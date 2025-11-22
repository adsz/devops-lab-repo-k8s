#!/bin/bash
# Sync all ArgoCD Applications

echo "🔄 Syncing all ArgoCD Applications..."
echo ""

if ! command -v argocd &> /dev/null; then
    echo "❌ argocd CLI not found"
    echo ""
    echo "Install with:"
    echo "  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    echo "  chmod +x /usr/local/bin/argocd"
    exit 1
fi

for app in blog-app-plain blog-app-kustomize blog-app-helm; do
    if kubectl get application "$app" -n argocd &> /dev/null; then
        echo "🔄 Syncing $app..."
        argocd app sync "$app" --prune || echo "  ⚠️  Sync failed for $app"
    else
        echo "⏭️  Skipping $app (not found)"
    fi
    echo ""
done

echo "✅ Sync complete"
echo ""
echo "📊 Check status:"
echo "  ./status.sh"
