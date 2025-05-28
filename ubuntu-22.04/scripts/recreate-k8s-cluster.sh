#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[$(date +'%F %T')] $1${NC}"; }
warn()   { echo -e "${YELLOW}[$(date +'%F %T')] WARNING: $1${NC}"; }
error()  { echo -e "${RED}[$(date +'%F %T')] ERROR: $1${NC}"; }
info()   { echo -e "${BLUE}[$(date +'%F %T')] INFO: $1${NC}"; }

check_location() {
    VAGRANT_DIR="$(dirname "$0")/../vagrant"
    if [[ ! -f "$VAGRANT_DIR/Vagrantfile" ]]; then
        error "vagrant/Vagrantfile not found at $VAGRANT_DIR"
        exit 1
    fi
    export VAGRANT_CWD="$VAGRANT_DIR"
}

check_prerequisites() {
    log "Checking prerequisites..."
    command -v vagrant >/dev/null || { error "Vagrant not found."; exit 1; }
    log "✓ Vagrant version: $(vagrant --version)"
}

list_k8s_vagrant_vms() {
    vagrant global-status --prune 2>/dev/null | grep -i 'k8s' | awk '{print $1, $2, $5}'
}

confirm_destruction() {
    mapfile -t VMS < <(list_k8s_vagrant_vms)

    if [[ "${#VMS[@]}" -eq 0 ]]; then
        log "No k8s Vagrant VMs found to destroy."
        return 1
    fi

    warn "The following Vagrant VMs will be destroyed:"
    printf "  %-10s %-20s %s\n" "ID" "Name" "Directory"
    for vm in "${VMS[@]}"; do
        echo "  $vm"
    done

    if [[ "$FORCE" != "true" ]]; then
        echo ""
        read -p "Type 'yes' to confirm destruction: " -r
        echo ""
        if [[ "$REPLY" != "yes" ]]; then
            info "Cancelled by user."
            exit 0
        fi
    fi

    return 0
}

destroy_existing_vms() {
    log "Destroying Vagrant-managed k8s VMs..."
    mapfile -t VMS_IDS < <(list_k8s_vagrant_vms | awk '{print $1}')

    for id in "${VMS_IDS[@]}"; do
        info "Destroying VM ID: $id"
        vagrant destroy -f "$id" || true
    done

    log "✓ All k8s Vagrant VMs destroyed."
}

create_new_vms() {
    log "Creating Vagrant VMs from Vagrantfile..."
    vagrant up || { error "vagrant up failed."; exit 1; }
    log "✓ All VMs created."
}

verify_vms() {
    log "Verifying VM SSH access..."
    vagrant status

    local failures=0
    for vm in $(vagrant status | awk '/running/{print $1}'); do
        info "Testing $vm..."
        if timeout 30 vagrant ssh "$vm" -c "echo OK" >/dev/null 2>&1; then
            log "✓ $vm SSH OK"
        else
            error "✗ $vm SSH FAILED"
            failures=$((failures + 1))
        fi
    done

    [[ "$failures" -gt 0 ]] && error "Some SSH checks failed." && exit 1
}

main() {
    log "K8s Cluster Vagrant Recreation Script"
    CREATE_SNAPSHOTS=false
    FORCE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)     FORCE=true ;;
            --help|-h)
                echo "Usage: $0 [--force]"
                echo "Destroys and recreates Vagrant k8s VMs."
                exit 0
                ;;
        esac
        shift
    done

    check_location
    check_prerequisites
    confirm_destruction && destroy_existing_vms
    sleep 2
    create_new_vms
    verify_vms

    log "🎉 Done. Vagrant k8s VMs recreated."
}

trap 'error "Failed at line $LINENO"' ERR
main "$@"
