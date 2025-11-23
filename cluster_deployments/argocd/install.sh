#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="argocd"
ARGOCD_VERSION="v2.13.2"  # Latest stable version

echo "========================================="
echo "ArgoCD Enterprise Installation"
echo "========================================="

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed"
    exit 1
fi

echo "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "Cluster is accessible"

# Create namespace
echo "Creating namespace: ${NAMESPACE}..."
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# Install ArgoCD using official manifests
echo "Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl apply -n ${NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

# Wait for initial deployment
echo "Waiting for ArgoCD components to be ready..."
sleep 10

# Apply custom configurations
echo "Applying enterprise configurations..."

# Apply LoadBalancer service
if [ -f "${SCRIPT_DIR}/argocd-server-lb.yaml" ]; then
    echo "Configuring LoadBalancer service..."
    kubectl apply -f "${SCRIPT_DIR}/argocd-server-lb.yaml"
fi

# Apply ingress
if [ -f "${SCRIPT_DIR}/ingress.yaml" ]; then
    echo "Configuring Ingress..."
    kubectl apply -f "${SCRIPT_DIR}/ingress.yaml"
fi

# Apply HA configuration
if [ -f "${SCRIPT_DIR}/ha-patch.yaml" ]; then
    echo "Applying HA configuration..."
    kubectl patch deployment argocd-server -n ${NAMESPACE} --patch-file "${SCRIPT_DIR}/ha-patch.yaml"
    kubectl patch deployment argocd-repo-server -n ${NAMESPACE} --patch-file "${SCRIPT_DIR}/ha-patch-repo.yaml"
    kubectl patch deployment argocd-applicationset-controller -n ${NAMESPACE} --patch-file "${SCRIPT_DIR}/ha-patch-appset.yaml"
fi

# Wait for all pods
echo "Waiting for all ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/part-of=argocd \
    -n ${NAMESPACE} \
    --timeout=300s

# Get initial admin password
echo ""
echo "========================================="
echo "ArgoCD Installation Complete!"
echo "========================================="
echo ""

INITIAL_PASSWORD=$(kubectl -n ${NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "Access Information:"
echo ""
echo "1. LoadBalancer IP:"
echo "   http://192.168.0.215"
echo ""
echo "2. Ingress (if configured):"
echo "   http://argocd.local"
echo ""
echo "3. Port Forward (alternative):"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   https://localhost:8080"
echo ""
echo "Login Credentials:"
echo "   Username: admin"
echo "   Password: ${INITIAL_PASSWORD}"
echo ""
echo "IMPORTANT: Change the admin password after first login!"
echo "   argocd account update-password"
echo ""
echo "To install ArgoCD CLI:"
echo "   curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
echo "   chmod +x argocd"
echo "   sudo mv argocd /usr/local/bin/"
echo ""