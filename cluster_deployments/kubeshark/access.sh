#!/bin/bash

set -e

NAMESPACE="kubeshark"
PORT="${1:-8899}"

echo "========================================="
echo "Kubeshark Dashboard Access"
echo "========================================="

# Check if namespace exists
if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
    echo "ERROR: Namespace '${NAMESPACE}' does not exist"
    echo "Please install Kubeshark first: ./install.sh"
    exit 1
fi

# Check if service exists
if ! kubectl get svc kubeshark-front -n "${NAMESPACE}" &> /dev/null; then
    echo "ERROR: Kubeshark service not found"
    exit 1
fi

echo "Starting port-forward to Kubeshark dashboard..."
echo ""
echo "Dashboard will be available at: http://localhost:${PORT}"
echo "Press Ctrl+C to stop port-forwarding"
echo ""

kubectl port-forward -n "${NAMESPACE}" svc/kubeshark-front "${PORT}:80"
