#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to destroy only Vagrant-managed VMs named k8s*
destroy_all_vms() {
    log "Destroying ONLY Vagrant-managed VMs named k8s*..."

    # Destroy VMs from current Vagrantfile if names match
    if [[ -d "vagrant" ]]; then
        cd vagrant/

        info "Checking Vagrant status:"
        vagrant status | grep '^k8s' | awk '{print $1}' | while read vm; do
            warn "Destroying local VM: $vm"
            vagrant destroy -f "$vm" 2>/dev/null || true
        done

        cd ../
    fi

    # Destroy globally tracked Vagrant VMs named k8s*
    warn "Destroying globally tracked Vagrant VMs named k8s*..."
    vagrant global-status --prune 2>/dev/null | grep 'k8s' | awk '{print $1}' | while read vm_id; do
        if [[ -n "$vm_id" ]]; then
            info "Destroying global VM ID: $vm_id"
            vagrant destroy "$vm_id" -f 2>/dev/null || true
        fi
    done

    log "✓ Selected Vagrant VMs destroyed."
}

# Function to create new VMs
create_new_vms() {
    log "Creating fresh new VMs..."

    if [[ ! -d "vagrant" ]]; then
        error "vagrant/ directory not found!"
        exit 1
    fi

    if [[ ! -f "vagrant/Vagrantfile" ]]; then
        error "vagrant/Vagrantfile not found!"
        exit 1
    fi

    cd vagrant/

    info "Creating VMs according to config.yml:"
    if [[ -f "config.yml" ]]; then
        echo ""
        grep -A 20 "nodes:" config.yml | grep -E "(k8s-|public_ip|role)" | while read line; do
            echo "  $line"
        done
        echo ""
    fi

    log "Starting VM creation..."
    vagrant up

    if [[ $? -eq 0 ]]; then
        log "✓ All VMs created successfully!"
    else
        error "VM creation failed!"
        exit 1
    fi

    cd ../
}

# Function to verify VMs
verify_new_vms() {
    log "Verifying new VMs..."

    cd vagrant/
    info "Vagrant status:"
    vagrant status
    cd ../

    log "Waiting for VMs to fully boot..."
    sleep 30

    log "Testing SSH connectivity..."
    if timeout 120 ansible all -i inventory.yml -m ping; then
        log "✓ All VMs are accessible via SSH!"
    else
        warn "Some VMs might not be ready yet. You can test manually with:"
        warn "ansible all -i inventory.yml -m ping"
    fi
}

# Function to display VM information
display_vm_info() {
    log "Fresh VMs Ready!"
    echo "=============================================="
    echo ""
    echo "Created VMs:"
    echo "  k8s-lb       : 192.168.0.175 (SSH: 2220) - Load Balancer"
    echo "  k8s-master-1 : 192.168.0.180 (SSH: 2221) - Master Node 1"
    echo "  k8s-master-2 : 192.168.0.181 (SSH: 2222) - Master Node 2"
    echo "  k8s-worker-1 : 192.168.0.190 (SSH: 2223) - Worker Node 1"
    echo "  k8s-worker-2 : 192.168.0.191 (SSH: 2224) - Worker Node 2"
    echo ""
    echo "VM Management:"
    echo "  cd vagrant/"
    echo "  vagrant status          - Check VM status"
    echo "  vagrant ssh <vm-name>   - SSH to specific VM"
    echo "  vagrant halt            - Stop all VMs"
    echo "  vagrant reload          - Restart all VMs"
    echo ""
    echo "Next Steps:"
    echo "  1. Test connectivity:"
    echo "     ansible all -i inventory.yml -m ping"
    echo ""
    echo "  2. Deploy Kubernetes:"
    echo "     ansible-playbook -i inventory.yml playbooks/site.yml"
    echo ""
    echo "=============================================="
}

# Main execution
main() {
    log "Fresh Vagrant VMs Creation Script"
    log "================================="

    FORCE=false
    VERIFY=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --no-verify)
                VERIFY=false
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "This script will:"
                echo "1. Destroy ONLY Vagrant-managed VMs named k8s*"
                echo "2. Create fresh new VMs from Vagrantfile"
                echo "3. Verify VM connectivity"
                echo ""
                echo "Options:"
                echo "  --force       Skip confirmation prompts"
                echo "  --no-verify   Skip SSH connectivity verification"
                echo "  --help, -h    Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if ! command -v vagrant &> /dev/null; then
        error "Vagrant is not installed!"
        exit 1
    fi

    if ! command -v VBoxManage &> /dev/null; then
        error "VirtualBox is not installed!"
        exit 1
    fi

    if [[ "$FORCE" != "true" ]]; then
        echo ""
        warn "⚠️  This will DESTROY ONLY Vagrant-managed VMs named k8s*!"
        echo ""
        read -p "Are you absolutely sure you want to continue? (type 'yes' to confirm): " -r
        echo ""
        if [[ "$REPLY" != "yes" ]]; then
            info "Operation cancelled."
            exit 0
        fi
    fi

    destroy_all_vms
    log "Waiting for cleanup to complete..."
    sleep 5

    create_new_vms

    if [[ "$VERIFY" == "true" ]]; then
        verify_new_vms
    fi

    display_vm_info

    log "🎉 Fresh VMs created successfully!"
    log "Ready for Kubernetes deployment!"
}

trap 'error "Script failed at line $LINENO"; exit 1' ERR

main "$@"
