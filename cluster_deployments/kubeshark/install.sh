#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="kubeshark"

echo "========================================="
echo "Kubeshark Installation Script"
echo "========================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "ERROR: helm is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
echo "Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "Cluster is accessible"

# Create namespace
echo "Creating namespace: ${NAMESPACE}..."
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# Add Helm repository if not already added
echo "Adding Kubeshark Helm repository..."
if ! helm repo list | grep -q "kubeshark"; then
    helm repo add kubeshark https://helm.kubeshark.co
fi

echo "Updating Helm repositories..."
helm repo update

# Install or upgrade Kubeshark
echo "Installing Kubeshark using Helm..."
helm upgrade --install kubeshark kubeshark/kubeshark \
    --namespace "${NAMESPACE}" \
    --values "${SCRIPT_DIR}/values.yaml" \
    --wait \
    --timeout 5m

# Wait for deployment
echo "Waiting for Kubeshark pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=kubeshark \
    -n "${NAMESPACE}" \
    --timeout=300s

# Show status
echo ""
echo "========================================="
echo "Kubeshark Installation Complete!"
echo "========================================="
echo ""
echo "Deployment status:"
kubectl get pods -n "${NAMESPACE}"
echo ""
echo "Services:"
kubectl get svc -n "${NAMESPACE}"
echo ""
echo "To access Kubeshark dashboard:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/kubeshark-front 8899:80"
echo "  Then open: http://localhost:8899"
echo ""
echo "To view logs:"
echo "  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=kubeshark -f"
echo ""
