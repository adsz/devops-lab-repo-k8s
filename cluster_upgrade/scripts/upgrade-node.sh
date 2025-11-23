#!/bin/bash
#
# Kubernetes Node Upgrade Script
# Automates upgrade of control plane or worker node
#
# Usage: ./upgrade-node.sh <node-type> <node-name> <target-version>
# Example: ./upgrade-node.sh master k8s-master-1 1.30.6
# Example: ./upgrade-node.sh worker k8s-worker-1 1.30.6

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validate arguments
if [ $# -ne 3 ]; then
    echo "Usage: $0 <node-type> <node-name> <target-version>"
    echo ""
    echo "Arguments:"
    echo "  node-type: master|worker"
    echo "  node-name: k8s-master-1|k8s-worker-1|k8s-worker-2"
    echo "  target-version: Kubernetes version without 'v' prefix (e.g., 1.30.6)"
    echo ""
    echo "Examples:"
    echo "  $0 master k8s-master-1 1.30.6"
    echo "  $0 worker k8s-worker-1 1.30.6"
    exit 1
fi

NODE_TYPE="$1"
NODE_NAME="$2"
TARGET_VERSION="$3"
K8S_VERSION="${TARGET_VERSION}-1.1"  # Debian package version format

# Validate node type
if [[ ! "$NODE_TYPE" =~ ^(master|worker)$ ]]; then
    echo -e "${RED}Error: node-type must be 'master' or 'worker'${NC}"
    exit 1
fi

# Get node IP
case "$NODE_NAME" in
    k8s-master-1)
        NODE_IP="192.168.0.180"
        ;;
    k8s-worker-1)
        NODE_IP="192.168.0.190"
        ;;
    k8s-worker-2)
        NODE_IP="192.168.0.191"
        ;;
    *)
        echo -e "${RED}Error: Unknown node name: $NODE_NAME${NC}"
        echo "Valid nodes: k8s-master-1, k8s-worker-1, k8s-worker-2"
        exit 1
        ;;
esac

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Kubernetes Node Upgrade${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Node Type: $NODE_TYPE"
echo "Node Name: $NODE_NAME"
echo "Node IP: $NODE_IP"
echo "Target Version: v$TARGET_VERSION"
echo "Timestamp: $(date)"
echo ""

# Confirmation
echo -e "${YELLOW}This will upgrade $NODE_NAME to Kubernetes v$TARGET_VERSION${NC}"
echo -e "${YELLOW}The node will be drained and upgraded.${NC}"
read -p "Do you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Upgrade cancelled."
    exit 0
fi

# Function to run command on node
run_on_node() {
    ssh ansible@"$NODE_IP" "$1"
}

# Function to run command on node with sudo
run_on_node_sudo() {
    ssh ansible@"$NODE_IP" "sudo $1"
}

# Step 1: Drain node
echo -e "\n${BLUE}[1/8]${NC} Draining node $NODE_NAME..."
if kubectl drain "$NODE_NAME" --ignore-daemonsets --delete-emptydir-data --timeout=300s; then
    echo -e "${GREEN}✓${NC} Node drained successfully"
else
    echo -e "${RED}✗${NC} Failed to drain node"
    exit 1
fi

# Step 2: Upgrade kubeadm
echo -e "\n${BLUE}[2/8]${NC} Upgrading kubeadm to v$TARGET_VERSION..."
run_on_node_sudo "apt-mark unhold kubeadm"
run_on_node_sudo "apt-get update"

if run_on_node_sudo "apt-get install -y kubeadm=$K8S_VERSION"; then
    run_on_node_sudo "apt-mark hold kubeadm"
    INSTALLED_KUBEADM=$(run_on_node "kubeadm version -o short")
    echo -e "${GREEN}✓${NC} kubeadm upgraded to $INSTALLED_KUBEADM"
else
    echo -e "${RED}✗${NC} Failed to upgrade kubeadm"
    kubectl uncordon "$NODE_NAME"
    exit 1
fi

# Step 3: Upgrade node (different for master vs worker)
if [ "$NODE_TYPE" = "master" ]; then
    echo -e "\n${BLUE}[3/8]${NC} Planning control plane upgrade..."
    echo "Available upgrade plan:"
    run_on_node_sudo "kubeadm upgrade plan"

    echo -e "\n${BLUE}[3/8]${NC} Applying control plane upgrade..."
    if run_on_node_sudo "kubeadm upgrade apply v$TARGET_VERSION -y"; then
        echo -e "${GREEN}✓${NC} Control plane upgraded successfully"
    else
        echo -e "${RED}✗${NC} Failed to upgrade control plane"
        kubectl uncordon "$NODE_NAME"
        exit 1
    fi
else
    echo -e "\n${BLUE}[3/8]${NC} Upgrading worker node configuration..."
    if run_on_node_sudo "kubeadm upgrade node"; then
        echo -e "${GREEN}✓${NC} Worker node upgraded successfully"
    else
        echo -e "${RED}✗${NC} Failed to upgrade worker node"
        kubectl uncordon "$NODE_NAME"
        exit 1
    fi
fi

# Step 4: Upgrade kubelet and kubectl
echo -e "\n${BLUE}[4/8]${NC} Upgrading kubelet and kubectl..."
run_on_node_sudo "apt-mark unhold kubelet kubectl"

if run_on_node_sudo "apt-get install -y kubelet=$K8S_VERSION kubectl=$K8S_VERSION"; then
    run_on_node_sudo "apt-mark hold kubelet kubectl"
    echo -e "${GREEN}✓${NC} kubelet and kubectl upgraded"
else
    echo -e "${RED}✗${NC} Failed to upgrade kubelet and kubectl"
    kubectl uncordon "$NODE_NAME"
    exit 1
fi

# Step 5: Restart kubelet
echo -e "\n${BLUE}[5/8]${NC} Restarting kubelet service..."
run_on_node_sudo "systemctl daemon-reload"
run_on_node_sudo "systemctl restart kubelet"

# Wait for kubelet to be ready
echo "Waiting for kubelet to become ready..."
sleep 10

if run_on_node_sudo "systemctl is-active kubelet" | grep -q "active"; then
    echo -e "${GREEN}✓${NC} kubelet restarted successfully"
else
    echo -e "${RED}✗${NC} kubelet failed to start"
    exit 1
fi

# Step 6: Uncordon node
echo -e "\n${BLUE}[6/8]${NC} Uncordoning node..."
if kubectl uncordon "$NODE_NAME"; then
    echo -e "${GREEN}✓${NC} Node uncordoned"
else
    echo -e "${RED}✗${NC} Failed to uncordon node"
    exit 1
fi

# Step 7: Wait for node to be Ready
echo -e "\n${BLUE}[7/8]${NC} Waiting for node to be Ready..."
for i in {1..30}; do
    NODE_STATUS=$(kubectl get node "$NODE_NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$NODE_STATUS" = "True" ]; then
        echo -e "${GREEN}✓${NC} Node is Ready"
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 10
done

if [ "$NODE_STATUS" != "True" ]; then
    echo -e "${RED}✗${NC} Node failed to become Ready"
    exit 1
fi

# Step 8: Verify upgrade
echo -e "\n${BLUE}[8/8]${NC} Verifying upgrade..."
NODE_VERSION=$(kubectl get node "$NODE_NAME" -o jsonpath='{.status.nodeInfo.kubeletVersion}')

if [[ "$NODE_VERSION" == *"$TARGET_VERSION"* ]]; then
    echo -e "${GREEN}✓${NC} Node version: $NODE_VERSION"
else
    echo -e "${YELLOW}⚠${NC} Node version: $NODE_VERSION (expected v$TARGET_VERSION)"
fi

# Show node info
echo ""
kubectl get node "$NODE_NAME" -o wide

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Upgrade completed successfully${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Node: $NODE_NAME"
echo "Previous Version: (check backup)"
echo "Current Version: $NODE_VERSION"
echo "Upgraded: $(date)"
echo ""
echo "Next steps:"
if [ "$NODE_TYPE" = "master" ]; then
    echo "  1. Verify control plane components:"
    echo "     kubectl get pods -n kube-system"
    echo "  2. Proceed with worker node upgrades"
else
    echo "  1. Verify pods on this node:"
    echo "     kubectl get pods -A --field-selector spec.nodeName=$NODE_NAME"
    echo "  2. Proceed with next worker node"
fi
echo ""

exit 0
