#!/bin/bash
# shutdown_k8s_cluster.sh
# Safely shutdown Kubernetes cluster (LB + CP + Workers)

set -uo pipefail

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

VAGRANT_DIR="/repos/devops-lab-new/devops-lab-repo-k8s/ubuntu-22.04/vagrant"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Kubernetes Cluster Safe Shutdown Script          ║${NC}"
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

# Get list of running VMs
echo -e "${BLUE}${INFO} Checking cluster VM status...${NC}\n"

LB_STATUS=$(check_vm_status "k8s-lb")
CP_STATUS=$(check_vm_status "k8s-master-1")
WN1_STATUS=$(check_vm_status "k8s-worker-1")
WN2_STATUS=$(check_vm_status "k8s-worker-2")

echo -e "${YELLOW}Current VM Status:${NC}"
echo -e "  k8s-lb (Load Balancer):  ${LB_STATUS}"
echo -e "  k8s-master-1 (CP):       ${CP_STATUS}"
echo -e "  k8s-worker-1 (WN1):      ${WN1_STATUS}"
echo -e "  k8s-worker-2 (WN2):      ${WN2_STATUS}"
echo ""

# Count running worker nodes
RUNNING_WORKERS=0
[[ "$WN1_STATUS" == "running" ]] && ((RUNNING_WORKERS++))
[[ "$WN2_STATUS" == "running" ]] && ((RUNNING_WORKERS++))

if [[ "$LB_STATUS" == "stopped" && "$CP_STATUS" == "stopped" && "$RUNNING_WORKERS" -eq 0 ]]; then
    echo -e "${GREEN}${CHECK} All VMs are already stopped. Nothing to do.${NC}"
    exit 0
fi

echo -e "${YELLOW}${WARNING} Shutting down entire Kubernetes cluster...${NC}"
echo -e "${YELLOW}${WARNING} All running pods will be terminated.${NC}"
echo ""

sleep 2
echo -e "${INFO} Starting shutdown sequence..."
echo ""

# Step 1: Shutdown Worker Nodes
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1/3: Shutting down Worker Nodes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [[ "$WN2_STATUS" == "running" ]]; then
    echo -e "${YELLOW}${INFO} Stopping k8s-worker-2...${NC}"
    vboxmanage controlvm k8s-worker-2 acpipowerbutton
    echo -e "${GREEN}${CHECK} k8s-worker-2 stopped${NC}\n"
    sleep 5
else
    echo -e "${INFO} k8s-worker-2 already stopped${NC}\n"
fi

if [[ "$WN1_STATUS" == "running" ]]; then
    echo -e "${YELLOW}${INFO} Stopping k8s-worker-1...${NC}"
    vboxmanage controlvm k8s-worker-1 acpipowerbutton
    echo -e "${GREEN}${CHECK} k8s-worker-1 stopped${NC}\n"
    sleep 5
else
    echo -e "${INFO} k8s-worker-1 already stopped${NC}\n"
fi

# Step 2: Shutdown Control Plane (Master)
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2/3: Shutting down Control Plane${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [[ "$CP_STATUS" == "running" ]]; then
    echo -e "${YELLOW}${INFO} Stopping k8s-master-1...${NC}"
    vboxmanage controlvm k8s-master-1 acpipowerbutton
    echo -e "${GREEN}${CHECK} k8s-master-1 stopped${NC}\n"
    sleep 5
else
    echo -e "${INFO} k8s-master-1 already stopped${NC}\n"
fi

# Step 3: Shutdown Load Balancer
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3/3: Shutting down Load Balancer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [[ "$LB_STATUS" == "running" ]]; then
    echo -e "${YELLOW}${INFO} Stopping k8s-lb...${NC}"
    vboxmanage controlvm k8s-lb acpipowerbutton
    echo -e "${GREEN}${CHECK} k8s-lb stopped${NC}\n"
    sleep 5
else
    echo -e "${INFO} k8s-lb already stopped${NC}\n"
fi

# Final verification
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Shutdown Complete - Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}Final VM Status:${NC}"
vboxmanage list vms | grep k8s | while read vm; do
    vm_name=$(echo "$vm" | cut -d'"' -f2)
    status=$(check_vm_status "$vm_name")
    echo "  $vm_name: $status"
done

echo -e "\n${GREEN}${CHECK} Kubernetes cluster shutdown completed successfully!${NC}"
echo -e "${INFO} To start the cluster again, run: ./startup_k8s_cluster.sh${NC}\n"
