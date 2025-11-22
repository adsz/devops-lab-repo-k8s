#!/bin/bash
# Deploy specific ArgoCD Application(s) for blog-app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [plain|kustomize|helm|all]"
    echo ""
    echo "Examples:"
    echo "  $0 plain      # Deploy only Plain YAML app"
    echo "  $0 kustomize  # Deploy only Kustomize app"
    echo "  $0 helm       # Deploy only Helm app"
    echo "  $0 all        # Deploy all 3 apps"
    exit 1
}

deploy_plain() {
    echo "📦 Deploying Plain YAML Application..."
    kubectl apply -f "$SCRIPT_DIR/plain-yaml-app.yaml"
    echo "✅ blog-app-plain created in ArgoCD"
}

deploy_kustomize() {
    echo "📦 Deploying Kustomize Application..."
    kubectl apply -f "$SCRIPT_DIR/kustomize-app.yaml"
    echo "✅ blog-app-kustomize created in ArgoCD"
}

deploy_helm() {
    echo "📦 Deploying Helm Application..."
    kubectl apply -f "$SCRIPT_DIR/helm-app.yaml"
    echo "✅ blog-app-helm created in ArgoCD"
}

deploy_all() {
    deploy_plain
    deploy_kustomize
    deploy_helm
}

# Main
case "${1:-}" in
    plain)
        deploy_plain
        ;;
    kustomize)
        deploy_kustomize
        ;;
    helm)
        deploy_helm
        ;;
    all)
        deploy_all
        ;;
    *)
        usage
        ;;
esac

echo ""
echo "🎯 Next steps:"
echo "  1. Check ArgoCD UI: https://argocd.devops-lab.cloud"
echo "  2. Sync application: argocd app sync blog-app-<method>"
echo "  3. Or use: ./sync-app.sh <method>"
