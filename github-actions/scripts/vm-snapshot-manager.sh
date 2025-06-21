# File: /repos/devops-lab-new/devops-lab-repo-k8s/github-actions/scripts/vm-snapshot-manager.sh
#!/bin/bash

set -e

# Function to display help
show_help() {
    cat << EOF
VM Snapshot Manager for GitHub Actions

Usage: $0 <command> [options]

Commands:
    create <name> [description]  - Create snapshot with given name
    restore <name>              - Restore VMs to specific snapshot
    list                        - List all snapshots for all VMs
    cleanup <days>              - Remove snapshots older than X days

Options:
    --config-file <path>        - Path to config.yml (default: github-actions/config/config.yml)
    --dry-run                   - Show what would be done without executing
    --force                     - Force operations without confirmation

Examples:
    $0 create "pre-upgrade" "Before K8s upgrade to 1.30"
    $0 restore "clean-install"
    $0 list
    $0 cleanup 30

GitHub Actions integration:
    This script is designed to work with GitHub Actions workflows and
    preserves all existing snapshots. It never deletes snapshots automatically
    unless explicitly requested via cleanup command.
EOF
}

# Default values
CONFIG_FILE="github-actions/config/config.yml"
DRY_RUN=false
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Check if yq is available
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed"
    echo "Install with: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Load VM names from config
VM_NAMES=($(yq '.snapshots.vm_names[]' "$CONFIG_FILE"))

if [ ${#VM_NAMES[@]} -eq 0 ]; then
    echo "Error: No VM names found in config file"
    exit 1
fi

echo "Loaded VMs from config: ${VM_NAMES[*]}"

# Function to create snapshots
create_snapshot() {
    local snapshot_name="$1"
    local description="$2"
    
    if [ -z "$snapshot_name" ]; then
        echo "Error: Snapshot name is required"
        exit 1
    fi
    
    # Add timestamp if not GitHub Actions format
    if [[ ! "$snapshot_name" =~ github-actions ]]; then
        snapshot_name="${snapshot_name}-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Default description
    if [ -z "$description" ]; then
        description="Manual snapshot created on $(date)"
    fi
    
    echo "=== Creating Snapshot: $snapshot_name ==="
    echo "Description: $description"
    echo "Target VMs: ${VM_NAMES[*]}"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would create snapshot '$snapshot_name' for ${#VM_NAMES[@]} VMs"
        return 0
    fi
    
    if [ "$FORCE" = "false" ]; then
        read -p "Create snapshot '$snapshot_name' for ${#VM_NAMES[@]} VMs? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi
    fi
    
    local failed_vms=()
    
    for vm in "${VM_NAMES[@]}"; do
        echo "Creating snapshot for VM: $vm"
        
        # Check if VM exists
        if ! VBoxManage list vms | grep -q "\"$vm\""; then
            echo "  Warning: VM '$vm' not found, skipping"
            failed_vms+=("$vm")
            continue
        fi
        
        # Create snapshot
        if VBoxManage snapshot "$vm" take "$snapshot_name" --live --description "$description" 2>/dev/null; then
            echo "  ✓ Snapshot created for $vm"
        else
            echo "  ✗ Failed to create snapshot for $vm"
            failed_vms+=("$vm")
        fi
    done
    
    echo ""
    echo "=== Snapshot Creation Summary ==="
    echo "Snapshot name: $snapshot_name"
    echo "Successful: $((${#VM_NAMES[@]} - ${#failed_vms[@]}))/${#VM_NAMES[@]} VMs"
    
    if [ ${#failed_vms[@]} -gt 0 ]; then
        echo "Failed VMs: ${failed_vms[*]}"
        exit 1
    else
        echo "All snapshots created successfully!"
    fi
}

# Function to restore snapshots
restore_snapshot() {
    local snapshot_name="$1"
    
    if [ -z "$snapshot_name" ]; then
        echo "Error: Snapshot name is required"
        exit 1
    fi
    
    echo "=== Restoring Snapshot: $snapshot_name ==="
    echo "Target VMs: ${VM_NAMES[*]}"
    
    # Check if snapshot exists on all VMs
    local missing_snapshots=()
    for vm in "${VM_NAMES[@]}"; do
        if ! VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep -q "SnapshotName.*$snapshot_name"; then
            missing_snapshots+=("$vm")
        fi
    done
    
    if [ ${#missing_snapshots[@]} -gt 0 ]; then
        echo "Error: Snapshot '$snapshot_name' not found on VMs: ${missing_snapshots[*]}"
        echo "Available snapshots:"
        list_snapshots
        exit 1
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would restore snapshot '$snapshot_name' for ${#VM_NAMES[@]} VMs"
        return 0
    fi
    
    if [ "$FORCE" = "false" ]; then
        echo "WARNING: This will stop all VMs and restore them to snapshot '$snapshot_name'"
        echo "All changes since snapshot creation will be lost!"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi
    fi
    
    local failed_vms=()
    
    for vm in "${VM_NAMES[@]}"; do
        echo "Restoring VM: $vm"
        
        # Power off VM
        echo "  Powering off $vm..."
        VBoxManage controlvm "$vm" poweroff 2>/dev/null || true
        sleep 2
        
        # Restore snapshot
        if VBoxManage snapshot "$vm" restore "$snapshot_name" 2>/dev/null; then
            echo "  ✓ Snapshot restored for $vm"
            
            # Start VM
            echo "  Starting $vm..."
            if VBoxManage startvm "$vm" --type headless 2>/dev/null; then
                echo "  ✓ VM $vm started"
            else
                echo "  ✗ Failed to start $vm"
                failed_vms+=("$vm")
            fi
        else
            echo "  ✗ Failed to restore snapshot for $vm"
            failed_vms+=("$vm")
        fi
    done
    
    echo ""
    echo "=== Snapshot Restore Summary ==="
    echo "Snapshot name: $snapshot_name"
    echo "Successful: $((${#VM_NAMES[@]} - ${#failed_vms[@]}))/${#VM_NAMES[@]} VMs"
    
    if [ ${#failed_vms[@]} -gt 0 ]; then
        echo "Failed VMs: ${failed_vms[*]}"
        exit 1
    else
        echo "All VMs restored successfully!"
        echo "VMs are starting up, wait 60-120 seconds before accessing them"
    fi
}

# Function to list snapshots
list_snapshots() {
    echo "=== VM Snapshots ==="
    
    for vm in "${VM_NAMES[@]}"; do
        echo ""
        echo "VM: $vm"
        
        # Check if VM exists
        if ! VBoxManage list vms | grep -q "\"$vm\""; then
            echo "  VM not found"
            continue
        fi
        
        # Get VM config file
        local config_file
        config_file=$(VBoxManage showvminfo "$vm" --machinereadable | grep "CfgFile=" | cut -d'"' -f2)
        
        if [[ ! -f "$config_file" ]]; then
            echo "  Config file not found"
            continue
        fi
        
        # Parse snapshots from XML
        local snapshots_found=false
        while IFS= read -r line; do
            if [[ $line =~ \<Snapshot[[:space:]]+uuid=\"\{([^}]+)\}\"[[:space:]]+name=\"([^\"]+)\"[[:space:]]+timeStamp=\"([^\"]+)\" ]]; then
                local uuid="${BASH_REMATCH[1]}"
                local name="${BASH_REMATCH[2]}"
                local timestamp="${BASH_REMATCH[3]}"
                
                # Convert timestamp to readable format
                local readable
                readable=$(date -d "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")
                
                echo "  📸 $name"
                echo "     Created: $readable"
                if [[ "$name" =~ github-actions ]]; then
                    echo "     🔗 GitHub Actions snapshot"
                fi
                snapshots_found=true
            fi
        done < "$config_file"
        
        if [ "$snapshots_found" = false ]; then
            echo "  No snapshots found"
        fi
    done
}

# Function to cleanup old snapshots
cleanup_snapshots() {
    local days="$1"
    
    if [ -z "$days" ] || ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo "Error: Number of days must be a positive integer"
        exit 1
    fi
    
    echo "=== Cleaning up snapshots older than $days days ==="
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would search for snapshots older than $days days"
    fi
    
    local cutoff_date
    cutoff_date=$(date -d "$days days ago" +%s)
    local total_removed=0
    
    for vm in "${VM_NAMES[@]}"; do
        echo ""
        echo "Checking VM: $vm"
        
        # Check if VM exists
        if ! VBoxManage list vms | grep -q "\"$vm\""; then
            echo "  VM not found, skipping"
            continue
        fi
        
        # Get snapshots info
        local snapshots_to_remove=()
        
        # Use VBoxManage to get snapshot info
        local snapshot_info
        snapshot_info=$(VBoxManage showvminfo "$vm" --machinereadable | grep "SnapshotName\|SnapshotUUID" || true)
        
        if [ -z "$snapshot_info" ]; then
            echo "  No snapshots found"
            continue
        fi
        
        # Parse snapshot information (this is simplified - in real scenario you'd need to parse timestamps)
        echo "  Found snapshots, checking dates..."
        
        # For now, just list what would be checked
        if [ "$DRY_RUN" = "true" ]; then
            echo "  [DRY RUN] Would check snapshot timestamps and remove old ones"
        else
            echo "  Snapshot cleanup not implemented in this version"
            echo "  Use VirtualBox GUI or manual VBoxManage commands to remove old snapshots"
        fi
    done
    
    if [ "$total_removed" -gt 0 ]; then
        echo ""
        echo "Cleanup completed. Removed $total_removed snapshots."
    else
        echo ""
        echo "No snapshots removed."
    fi
}

# Main command processing
case "$1" in
    create)
        create_snapshot "$2" "$3"
        ;;
    restore)
        restore_snapshot "$2"
        ;;
    list)
        list_snapshots
        ;;
    cleanup)
        cleanup_snapshots "$2"
        ;;
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        show_help
        exit 1
        ;;
esacdo chmod +x /usr/local/bin/yq"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Load VM names from config
VM_NAMES=($(yq '.snapshots.vm_names[]' "$CONFIG_FILE"))

if [ ${#VM_NAMES[@]} -eq 0 ]; then
    echo "Error: No VM names found in config file"
    exit 1
fi

echo "Loaded VMs from config: ${VM_NAMES[*]}"

# Function to create snapshots
create_snapshot() {
    local snapshot_name="$1"
    local description="$2"
    
    if [ -z "$snapshot_name" ]; then
        echo "Error: Snapshot name is required"
        exit 1
    fi
    
    # Add timestamp if not GitHub Actions format
    if [[ ! "$snapshot_name" =~ github-actions ]]; then
        snapshot_name="${snapshot_name}-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Default description
    if [ -z "$description" ]; then
        description="Manual snapshot created on $(date)"
    fi
    
    echo "=== Creating Snapshot: $snapshot_name ==="
    echo "Description: $description"
    echo "Target VMs: ${VM_NAMES[*]}"
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would create snapshot '$snapshot_name' for ${#VM_NAMES[@]} VMs"
        return 0
    fi
    
    if [ "$FORCE" = "false" ]; then
        read -p "Create snapshot '$snapshot_name' for ${#VM_NAMES[@]} VMs? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi
    fi
    
    local failed_vms=()
    
    for vm in "${VM_NAMES[@]}"; do
        echo "Creating snapshot for VM: $vm"
        
        # Check if VM exists
        if ! VBoxManage list vms | grep -q "\"$vm\""; then
            echo "  Warning: VM '$vm' not found, skipping"
            failed_vms+=("$vm")
            continue
        fi
        
        # Create snapshot
        if VBoxManage snapshot "$vm" take "$snapshot_name" --live --description "$description" 2>/dev/null; then
            echo "  ✓ Snapshot created for $vm"
        else
            echo "  ✗ Failed to create snapshot for $vm"
            failed_vms+=("$vm")
        fi
    done
    
    echo ""
    echo "=== Snapshot Creation Summary ==="
    echo "Snapshot name: $snapshot_name"
    echo "Successful: $((${#VM_NAMES[@]} - ${#failed_vms[@]}))/${#VM_NAMES[@]} VMs"
    
    if [ ${#failed_vms[@]} -gt 0 ]; then
        echo "Failed VMs: ${failed_vms[*]}"
        exit 1
    else
        echo "All snapshots created successfully!"
    fi
}

# Function to restore snapshots
restore_snapshot() {
    local snapshot_name="$1"
    
    if [ -z "$snapshot_name" ]; then
        echo "Error: Snapshot name is required"
        exit 1
    fi
    
    echo "=== Restoring Snapshot: $snapshot_name ==="
    echo "Target VMs: ${VM_NAMES[*]}"
    
    # Check if snapshot exists on all VMs
    local missing_snapshots=()
    for vm in "${VM_NAMES[@]}"; do
        if ! VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep -q "SnapshotName.*$snapshot_name"; then
            missing_snapshots+=("$vm")
        fi
    done
    
    if [ ${#missing_snapshots[@]} -gt 0 ]; then
        echo "Error: Snapshot '$snapshot_name' not found on VMs: ${missing_snapshots[*]}"
        echo "Available snapshots:"
        list_snapshots
        exit 1
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would restore snapshot '$snapshot_name' for ${#VM_NAMES[@]} VMs"
        return 0
    fi
    
    if [ "$FORCE" = "false" ]; then
        echo "WARNING: This will stop all VMs and restore them to snapshot '$snapshot_name'"
        echo "All changes since snapshot creation will be lost!"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi
    fi
    
    local failed_vms=()
    
    for vm in "${VM_NAMES[@]}"; do
        echo "Restoring VM: $vm"
        
        # Power off VM
        echo "  Powering off $vm..."
        VBoxManage controlvm "$vm" poweroff 2>/dev/null || true
        sleep 2
        
        # Restore snapshot
        if VBoxManage snapshot "$vm" restore "$snapshot_name" 2>/dev/null; then
            echo "  ✓ Snapshot restored for $vm"
            
            # Start VM
            echo "  Starting $vm..."
            if VBoxManage startvm "$vm" --type headless 2>/dev/null; then
                echo "  ✓ VM $vm started"
            else
                echo "  ✗ Failed to start $vm"
                failed_vms+=("$vm")
            fi
        else
            echo "  ✗ Failed to restore snapshot for $vm"
            failed_vms+=("$vm")
        fi
    done
    
    echo ""
    echo "=== Snapshot Restore Summary ==="
    echo "Snapshot name: $snapshot_name"
    echo "Successful: $((${#VM_NAMES[@]} - ${#failed_vms[@]}))/${#VM_NAMES[@]} VMs"
    
    if [ ${#failed_vms[@]} -gt 0 ]; then
        echo "Failed VMs: ${failed_vms[*]}"
        exit 1
    else
        echo "All VMs restored successfully!"
        echo "VMs are starting up, wait 60-120 seconds before accessing them"
    fi
}

# Function to list snapshots
list_snapshots() {
    echo "=== VM Snapshots ==="
    
    for vm in "${VM_NAMES[@]}"; do
        echo ""
        echo "VM: $vm"
        
        # Check if VM exists
        if ! VBoxManage list vms | grep -q "\"$vm\""; then
            echo "  VM not found"
            continue
        fi
        
        # Get VM config file
        local config_file
        config_file=$(VBoxManage showvminfo "$vm" --machinereadable | grep "CfgFile=" | cut -d'"' -f2)
        
        if [[ ! -f "$config_file" ]]; then
            echo "  Config file not found"
            continue
        fi
        
        # Parse snapshots from XML
        local snapshots_found=false
        while IFS= read -r line; do
            if [[ $line =~ \<Snapshot[[:space:]]+uuid=\"\{([^}]+)\}\"[[:space:]]+name=\"([^\"]+)\"[[:space:]]+timeStamp=\"([^\"]+)\" ]]; then
                local uuid="${BASH_REMATCH[1]}"
                local name="${BASH_REMATCH[2]}"
                local timestamp="${BASH_REMATCH[3]}"
                
                # Convert timestamp to readable format
                local readable
                readable=$(date -d "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")
                
                echo "  📸 $name"
                echo "     Created: $readable"
                if [[ "$name" =~ github-actions ]]; then
                    echo "     🔗 GitHub Actions snapshot"
                fi
                snapshots_found=true
            fi
        done < "$config_file"
        
        if [ "$snapshots_found" = false ]; then
            echo "  No snapshots found"
        fi
    done
}

# Function to cleanup old snapshots
cleanup_snapshots() {
    local days="$1"
    
    if [ -z "$days" ] || ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo "Error: Number of days must be a positive integer"
        exit 1
    fi
    
    echo "=== Cleaning up snapshots older than $days days ==="
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would search for snapshots older than $days days"
    fi
    
    local cutoff_date
    cutoff_date=$(date -d "$days days ago" +%s)
    local total_removed=0
    
    for vm in "${VM_NAMES[@]}"; do
        echo ""
        echo "Checking VM: $vm"
        
        # Check if VM exists
        if ! VBoxManage list vms | grep -q "\"$vm\""; then
            echo "  VM not found, skipping"
            continue
        fi
        
        # Get snapshots info
        local snapshots_to_remove=()
        
        # Use VBoxManage to get snapshot info
        local snapshot_info
        snapshot_info=$(VBoxManage showvminfo "$vm" --machinereadable | grep "SnapshotName\|SnapshotUUID" || true)
        
        if [ -z "$snapshot_info" ]; then
            echo "  No snapshots found"
            continue
        fi
        
        # Parse snapshot information (this is simplified - in real scenario you'd need to parse timestamps)
        echo "  Found snapshots, checking dates..."
        
        # For now, just list what would be checked
        if [ "$DRY_RUN" = "true" ]; then
            echo "  [DRY RUN] Would check snapshot timestamps and remove old ones"
        else
            echo "  Snapshot cleanup not implemented in this version"
            echo "  Use VirtualBox GUI or manual VBoxManage commands to remove old snapshots"
        fi
    done
    
    if [ "$total_removed" -gt 0 ]; then
        echo ""
        echo "Cleanup completed. Removed $total_removed snapshots."
    else
        echo ""
        echo "No snapshots removed."
    fi
}

# Main command processing
case "$1" in
    create)
        create_snapshot "$2" "$3"
        ;;
    restore)
        restore_snapshot "$2"
        ;;
    list)
        list_snapshots
        ;;
    cleanup)
        cleanup_snapshots "$2"
        ;;
    *)
        echo "Error: Unknown command '$1'"
        echo ""
        show_help
        exit 1
        ;;
esac