#!/bin/bash
# Apply/Update all ArgoCD Applications

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Applying all ArgoCD Applications..."
kubectl apply -f "$SCRIPT_DIR/plain-yaml-app.yaml"
kubectl apply -f "$SCRIPT_DIR/kustomize-app.yaml"
kubectl apply -f "$SCRIPT_DIR/helm-app.yaml"

echo ""
echo "✅ All ArgoCD Applications applied/updated"
echo ""
echo "📊 Check status:"
echo "  kubectl get applications -n argocd | grep blog-app"
echo ""
echo "🌐 ArgoCD UI:"
echo "  https://argocd.devops-lab.cloud"
