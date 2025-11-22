#!/bin/bash
# Remove all ArgoCD Applications (but keep deployed resources)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🗑️  Removing all ArgoCD Applications..."
echo ""
echo "⚠️  Note: This removes Applications from ArgoCD but keeps deployed resources in cluster"
echo "    To also delete resources, use: argocd app delete <app> --cascade"
echo ""

kubectl delete -f "$SCRIPT_DIR/plain-yaml-app.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/kustomize-app.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/helm-app.yaml" --ignore-not-found

echo ""
echo "✅ All ArgoCD Applications removed"
echo ""
echo "📊 Verify:"
echo "  kubectl get applications -n argocd | grep blog-app"
