#!/bin/bash
# Sync specific ArgoCD Application(s) for blog-app

set -e

usage() {
    echo "Usage: $0 [plain|kustomize|helm|all]"
    echo ""
    echo "Examples:"
    echo "  $0 plain      # Sync only Plain YAML app"
    echo "  $0 kustomize  # Sync only Kustomize app"
    echo "  $0 helm       # Sync only Helm app"
    echo "  $0 all        # Sync all 3 apps"
    exit 1
}

sync_plain() {
    echo "🔄 Syncing Plain YAML Application..."
    argocd app sync blog-app-plain --prune
    echo "✅ blog-app-plain synced"
}

sync_kustomize() {
    echo "🔄 Syncing Kustomize Application..."
    argocd app sync blog-app-kustomize --prune
    echo "✅ blog-app-kustomize synced"
}

sync_helm() {
    echo "🔄 Syncing Helm Application..."
    argocd app sync blog-app-helm --prune
    echo "✅ blog-app-helm synced"
}

sync_all() {
    sync_plain
    sync_kustomize
    sync_helm
}

# Main
case "${1:-}" in
    plain)
        sync_plain
        ;;
    kustomize)
        sync_kustomize
        ;;
    helm)
        sync_helm
        ;;
    all)
        sync_all
        ;;
    *)
        usage
        ;;
esac

echo ""
echo "🌐 Access URLs:"
echo "  Plain:     http://192.168.0.190:30080"
echo "  Kustomize: http://192.168.0.190:30081"
echo "  Helm:      http://192.168.0.190:30082"
