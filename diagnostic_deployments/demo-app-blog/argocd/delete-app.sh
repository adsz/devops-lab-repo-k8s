#!/bin/bash
# Delete specific ArgoCD Application(s) for blog-app

set -e

usage() {
    echo "Usage: $0 [plain|kustomize|helm|all]"
    echo ""
    echo "Examples:"
    echo "  $0 plain      # Delete only Plain YAML app"
    echo "  $0 kustomize  # Delete only Kustomize app"
    echo "  $0 helm       # Delete only Helm app"
    echo "  $0 all        # Delete all 3 apps"
    exit 1
}

delete_plain() {
    echo "🗑️  Deleting Plain YAML Application..."
    argocd app delete blog-app-plain --cascade --yes 2>/dev/null || kubectl delete -f "$SCRIPT_DIR/plain-yaml-app.yaml"
    echo "✅ blog-app-plain deleted"
}

delete_kustomize() {
    echo "🗑️  Deleting Kustomize Application..."
    argocd app delete blog-app-kustomize --cascade --yes 2>/dev/null || kubectl delete -f "$SCRIPT_DIR/kustomize-app.yaml"
    echo "✅ blog-app-kustomize deleted"
}

delete_helm() {
    echo "🗑️  Deleting Helm Application..."
    argocd app delete blog-app-helm --cascade --yes 2>/dev/null || kubectl delete -f "$SCRIPT_DIR/helm-app.yaml"
    echo "✅ blog-app-helm deleted"
}

delete_all() {
    delete_plain
    delete_kustomize
    delete_helm
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Main
case "${1:-}" in
    plain)
        delete_plain
        ;;
    kustomize)
        delete_kustomize
        ;;
    helm)
        delete_helm
        ;;
    all)
        delete_all
        ;;
    *)
        usage
        ;;
esac

echo ""
echo "✅ Application(s) deleted from ArgoCD"
