#!/bin/bash
# startup_k8s_cluster.sh
# Safely startup Kubernetes cluster (LB + CP + Workers)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Icons
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"

VAGRANT_DIR="/repos/devops-lab-new/k8s-local/ubuntu-22.04/vagrant"
WAIT_LB=30
WAIT_CP=120
WAIT_WN=60

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Kubernetes Cluster Safe Startup Script           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

# Check if running from correct directory
if [[ ! -d "$VAGRANT_DIR" ]]; then
    echo -e "${RED}${CROSS} Error: Vagrant directory not found: $VAGRANT_DIR${NC}"
    exit 1
fi

cd "$VAGRANT_DIR"

# Function to check VM status
check_vm_status() {
    local vm_name="$1"
    vboxmanage showvminfo "$vm_name" 2>/dev/null | grep -q "State:.*running" && echo "running" || echo "stopped"
}

# Function to wait with countdown
wait_with_countdown() {
    local seconds=$1
    local message=$2
    echo -e "${YELLOW}${INFO} ${message} (${seconds}s)${NC}"
    for ((i=seconds; i>0; i--)); do
        printf "\r${YELLOW}  Waiting: %02d seconds remaining...${NC}" "$i"
        sleep 1
    done
    printf "\r${GREEN}${CHECK} Wait complete!                    ${NC}\n\n"
}

# Function to wait for SSH availability
wait_for_ssh() {
    local host=$1
    local max_wait=${2:-60}
    local elapsed=0

    echo -e "${YELLOW}${INFO} Waiting for SSH on ${host}...${NC}"

    while [ $elapsed -lt $max_wait ]; do
        if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no ansible@${host} "echo OK" &>/dev/null; then
            echo -e "${GREEN}${CHECK} SSH ready on ${host}${NC}\n"
            return 0
        fi
        printf "\r${YELLOW}  Waiting for SSH: %02d/%02d seconds...${NC}" "$elapsed" "$max_wait"
        sleep 2
        ((elapsed+=2))
    done

    echo -e "\n${YELLOW}${WARNING} SSH timeout on ${host} after ${max_wait}s (VM may still be booting)${NC}\n"
    return 1
}

# Get list of VM statuses
echo -e "${BLUE}${INFO} Checking cluster VM status...${NC}\n"

# LB_STATUS=$(check_vm_status "k8s-lb")  # LB disabled - using direct CP connection
CP_STATUS=$(check_vm_status "k8s-master-1")
WN1_STATUS=$(check_vm_status "k8s-worker-1")
WN2_STATUS=$(check_vm_status "k8s-worker-2")

echo -e "${YELLOW}Current VM Status:${NC}"
# echo -e "  k8s-lb (Load Balancer):  ${LB_STATUS}"  # LB disabled
echo -e "  k8s-master-1 (CP):       ${CP_STATUS}"
echo -e "  k8s-worker-1 (WN1):      ${WN1_STATUS}"
echo -e "  k8s-worker-2 (WN2):      ${WN2_STATUS}"
echo ""

# Check if all VMs are already running
RUNNING_WORKERS=0
[[ "$WN1_STATUS" == "running" ]] && ((RUNNING_WORKERS++))
[[ "$WN2_STATUS" == "running" ]] && ((RUNNING_WORKERS++))

if [[ "$CP_STATUS" == "running" && "$RUNNING_WORKERS" -eq 2 ]]; then
    echo -e "${GREEN}${CHECK} Cluster is already running!${NC}"
    echo -e "${INFO} Running cluster health check...${NC}\n"

    # Quick health check
    if kubectl get nodes &>/dev/null; then
        kubectl get nodes
        echo ""
        echo -e "${GREEN}${CHECK} Kubernetes cluster is healthy and responsive!${NC}"
    else
        echo -e "${YELLOW}${WARNING} Cluster VMs are running but API server might still be starting...${NC}"
        echo -e "${INFO} Wait a minute and check with: kubectl get nodes${NC}"
    fi
    exit 0
fi

echo -e "${BLUE}${ROCKET} Starting Kubernetes cluster (CP + Workers only)...${NC}\n"

# Step 1: Start Load Balancer - DISABLED (using direct CP connection)
# echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
# echo -e "${BLUE}Step 1/3: Starting Load Balancer${NC}"
# echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
#
# if [[ "$LB_STATUS" == "stopped" ]]; then
#     echo -e "${YELLOW}${INFO} Starting k8s-lb...${NC}"
#     vboxmanage startvm k8s-lb --type headless
#     echo -e "${GREEN}${CHECK} k8s-lb VM started${NC}\n"
#     wait_for_ssh 192.168.0.175 60
#     echo -e "${INFO} Waiting additional time for HAProxy to initialize...${NC}"
#     sleep 10
# else
#     echo -e "${GREEN}${CHECK} k8s-lb already running${NC}\n"
# fi

# Step 1: Start Control Plane (Master)
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1/2: Starting Control Plane${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [[ "$CP_STATUS" == "stopped" ]]; then
    echo -e "${YELLOW}${INFO} Starting k8s-master-1...${NC}"
    vboxmanage startvm k8s-master-1 --type headless
    echo -e "${GREEN}${CHECK} k8s-master-1 VM started${NC}\n"
    wait_for_ssh 192.168.0.180 90
    echo -e "${INFO} Waiting additional time for etcd, API server, controller-manager, and scheduler...${NC}"
    sleep 30
else
    echo -e "${GREEN}${CHECK} k8s-master-1 already running${NC}\n"
fi

# Step 2: Start Worker Nodes
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2/2: Starting Worker Nodes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

WORKERS_STARTED=0

if [[ "$WN1_STATUS" == "stopped" ]]; then
    echo -e "${YELLOW}${INFO} Starting k8s-worker-1...${NC}"
    vboxmanage startvm k8s-worker-1 --type headless
    echo -e "${GREEN}${CHECK} k8s-worker-1 VM started${NC}\n"
    wait_for_ssh 192.168.0.190 90
    ((WORKERS_STARTED++))
else
    echo -e "${GREEN}${CHECK} k8s-worker-1 already running${NC}\n"
fi

if [[ "$WN2_STATUS" == "stopped" ]]; then
    echo -e "${YELLOW}${INFO} Starting k8s-worker-2...${NC}"
    vboxmanage startvm k8s-worker-2 --type headless
    echo -e "${GREEN}${CHECK} k8s-worker-2 VM started${NC}\n"
    wait_for_ssh 192.168.0.191 90
    ((WORKERS_STARTED++))
else
    echo -e "${INFO} k8s-worker-2 remains stopped (optional)${NC}\n"
fi

if [[ $WORKERS_STARTED -gt 0 ]]; then
    echo -e "${INFO} Waiting additional time for kubelet and container runtime...${NC}"
    sleep 20
fi

# Final verification
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Startup Complete - Cluster Health Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}VirtualBox VM Status:${NC}"
vboxmanage list vms | grep k8s | while read vm; do
    vm_name=$(echo "$vm" | cut -d'"' -f2)
    status=$(check_vm_status "$vm_name")
    echo "  $vm_name: $status"
done
echo ""

echo -e "${YELLOW}${INFO} Checking Kubernetes cluster status...${NC}"

# Wait a bit more if needed
sleep 10

if kubectl get nodes &>/dev/null; then
    echo -e "\n${GREEN}${CHECK} Kubernetes API server is responsive!${NC}\n"

    echo -e "${YELLOW}Node Status:${NC}"
    kubectl get nodes -o wide

    echo -e "\n${YELLOW}System Pods Status:${NC}"
    kubectl get pods -n kube-system | head -15

    echo -e "\n${GREEN}${CHECK} Kubernetes cluster startup completed successfully!${NC}"
    echo -e "${INFO} Cluster is ready for workloads.${NC}\n"

    # Check for NotReady nodes
    NOT_READY=$(kubectl get nodes --no-headers | grep -c "NotReady" || echo "0")
    if [[ $NOT_READY -gt 0 ]]; then
        echo -e "${YELLOW}${WARNING} Warning: ${NOT_READY} node(s) are NotReady${NC}"
        echo -e "${INFO} This is normal during startup. Wait 1-2 minutes and check again:${NC}"
        echo -e "${INFO}   kubectl get nodes${NC}\n"
    fi
else
    echo -e "${YELLOW}${WARNING} Kubernetes API server is not responding yet${NC}"
    echo -e "${INFO} This is normal - control plane components are still initializing${NC}"
    echo -e "${INFO} Wait 1-2 minutes and check manually:${NC}"
    echo -e "${INFO}   kubectl get nodes${NC}"
    echo -e "${INFO}   kubectl get pods -A${NC}\n"
fi

echo -e "${GREEN}${ROCKET} Cluster startup sequence complete!${NC}\n"
