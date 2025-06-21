#!/bin/bash
# File: ubuntu-22.04/github-actions/scripts/vm-snapshot-manager.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# VM list from inventory
VM_LIST=(
    "k8s-lb"
    "k8s-master-1"
    "k8s-master-2"
    "k8s-worker-1"
    "k8s-worker-2"
)

usage() {
    echo "Usage: $0 <action> [snapshot_name]"
    echo "Actions:"
    echo "  snapshot_create <name>   - Create snapshots for all VMs"
    echo "  snapshot_restore <name>  - Restore snapshots for all VMs"
    echo "  snapshot_list           - List all snapshots"
    echo "  snapshot_delete <name>  - Delete snapshots for all VMs"
    exit 1
}

check_vm_exists() {
    local vm_name="$1"
    if ! VBoxManage list vms | grep -q "\"$vm_name\""; then
        echo "Warning: VM $vm_name not found"
        return 1
    fi
    return 0
}

create_snapshots() {
    local snapshot_name="$1"
    echo "Creating snapshots with name: $snapshot_name"
    
    for vm in "${VM_LIST[@]}"; do
        if check_vm_exists "$vm"; then
            echo "Creating snapshot for $vm..."
            VBoxManage snapshot "$vm" take "$snapshot_name" --live || {
                echo "Failed to create snapshot for $vm"
                continue
            }
            echo "✓ Snapshot created for $vm"
        fi
    done
}

restore_snapshots() {
    local snapshot_name="$1"
    echo "Restoring snapshots with name: $snapshot_name"
    
    for vm in "${VM_LIST[@]}"; do
        if check_vm_exists "$vm"; then
            echo "Stopping $vm..."
            VBoxManage controlvm "$vm" poweroff 2>/dev/null || true
            sleep 5
            
            echo "Restoring snapshot for $vm..."
            VBoxManage snapshot "$vm" restore "$snapshot_name" || {
                echo "Failed to restore snapshot for $vm"
                continue
            }
            
            echo "Starting $vm..."
            VBoxManage startvm "$vm" --type headless
            echo "✓ Snapshot restored for $vm"
        fi
    done
    
    echo "Waiting 300 seconds for VMs to boot..."
    sleep 300
}

list_snapshots() {
    echo "Listing snapshots for all VMs:"
    
    for vm in "${VM_LIST[@]}"; do
        if check_vm_exists "$vm"; then
            echo "VM: $vm"
            
            # Get snapshots using showvminfo
            local snapshots
            snapshots=$(VBoxManage showvminfo "$vm" --machinereadable | grep "SnapshotName" || true)
            
            if [ -z "$snapshots" ]; then
                echo "  No snapshots"
            else
                echo "$snapshots" | while IFS= read -r line; do
                    local name
                    name=$(echo "$line" | cut -d'=' -f2 | tr -d '"')
                    echo "  Snapshot: $name"
                done
            fi
            echo
        fi
    done
}

delete_snapshots() {
    local snapshot_name="$1"
    echo "Deleting snapshots with name: $snapshot_name"
    
    for vm in "${VM_LIST[@]}"; do
        if check_vm_exists "$vm"; then
            echo "Deleting snapshot for $vm..."
            VBoxManage snapshot "$vm" delete "$snapshot_name" || {
                echo "Failed to delete snapshot for $vm (may not exist)"
                continue
            }
            echo "✓ Snapshot deleted for $vm"
        fi
    done
}

cleanup_old_snapshots() {
    local retention_count="${1:-7}"
    echo "Cleaning up old snapshots (keeping last $retention_count)..."
    
    # This is a simplified cleanup - in production you'd want more sophisticated logic
    for vm in "${VM_LIST[@]}"; do
        if check_vm_exists "$vm"; then
            echo "Checking snapshots for $vm..."
            # Implementation would depend on your snapshot naming convention
        fi
    done
}

# Main script logic
ACTION="$1"
SNAPSHOT_NAME="$2"

case "$ACTION" in
    snapshot_create)
        if [ -z "$SNAPSHOT_NAME" ]; then
            SNAPSHOT_NAME="auto-$(date +%Y%m%d-%H%M%S)"
        fi
        create_snapshots "$SNAPSHOT_NAME"
        ;;
    snapshot_restore)
        if [ -z "$SNAPSHOT_NAME" ]; then
            echo "Error: Snapshot name required for restore"
            usage
        fi
        restore_snapshots "$SNAPSHOT_NAME"
        ;;
    snapshot_list)
        list_snapshots
        ;;
    snapshot_delete)
        if [ -z "$SNAPSHOT_NAME" ]; then
            echo "Error: Snapshot name required for delete"
            usage
        fi
        delete_snapshots "$SNAPSHOT_NAME"
        ;;
    snapshot_cleanup)
        cleanup_old_snapshots "${SNAPSHOT_NAME:-7}"
        ;;
    *)
        usage
        ;;
esac

echo "VM snapshot operation completed: $ACTION"