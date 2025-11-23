#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="longhorn-system"
RELEASE_NAME="longhorn"

echo "========================================="
echo "Longhorn Installation Script"
echo "========================================="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH"
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm is not installed or not in PATH"
  exit 1
fi

echo "Checking Kubernetes cluster connectivity..."
if ! kubectl version --output=yaml >/dev/null 2>&1; then
  echo "ERROR: Unable to communicate with the Kubernetes API"
  exit 1
fi

echo "Adding Longhorn Helm repository..."
if ! helm repo list | grep -q "^longhorn"; then
  helm repo add longhorn https://charts.longhorn.io
fi

echo "Updating Helm repositories..."
helm repo update

echo "Installing or upgrading Longhorn (${RELEASE_NAME})..."
helm upgrade --install "${RELEASE_NAME}" longhorn/longhorn \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --values "${SCRIPT_DIR}/values.yaml" \
  --wait \
  --timeout 15m

echo "Waiting for Longhorn components to be ready..."
kubectl -n "${NAMESPACE}" rollout status deployment longhorn-driver-deployer --timeout=600s
kubectl -n "${NAMESPACE}" rollout status daemonset longhorn-manager --timeout=600s

if [[ -f "${SCRIPT_DIR}/storageclasses.yaml" ]]; then
  echo "Applying additional Longhorn storage classes..."
  if ! kubectl apply -f "${SCRIPT_DIR}/storageclasses.yaml"; then
    echo "Reapplying storage classes after cleanup..."
    kubectl delete -f "${SCRIPT_DIR}/storageclasses.yaml" --ignore-not-found
    kubectl apply -f "${SCRIPT_DIR}/storageclasses.yaml"
  fi
fi

echo ""
echo "========================================="
echo "Longhorn installation complete!"
echo "========================================="
kubectl -n "${NAMESPACE}" get pods
echo ""
echo "UI service:"
kubectl -n "${NAMESPACE}" get svc longhorn-frontend
echo ""
echo "StorageClasses:"
kubectl get storageclass | grep -E 'longhorn'
