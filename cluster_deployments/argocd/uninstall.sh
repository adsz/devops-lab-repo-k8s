#!/bin/bash

set -e

NAMESPACE="argocd"

echo "========================================="
echo "ArgoCD Uninstallation"
echo "========================================="

read -p "Are you sure you want to uninstall ArgoCD? This will delete all applications! (yes/no): " -r
echo

if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo "Deleting ArgoCD resources..."

# Delete custom resources first
kubectl delete applications --all -n ${NAMESPACE} 2>/dev/null || true
kubectl delete appprojects --all -n ${NAMESPACE} 2>/dev/null || true

# Delete namespace (this will delete all resources)
kubectl delete namespace ${NAMESPACE}

echo ""
echo "========================================="
echo "ArgoCD Uninstallation Complete!"
echo "========================================="
