#!/bin/bash

set -e

NAMESPACE="kubeshark"

echo "========================================="
echo "Kubeshark Uninstallation Script"
echo "========================================="

# Uninstall Helm release
echo "Uninstalling Kubeshark Helm release..."
helm uninstall kubeshark -n "${NAMESPACE}" || true

# Delete namespace
echo "Deleting namespace: ${NAMESPACE}..."
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true

echo ""
echo "========================================="
echo "Kubeshark Uninstallation Complete!"
echo "========================================="
