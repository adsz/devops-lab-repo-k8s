#!/bin/bash
# Show status of all ArgoCD Applications

echo "📊 ArgoCD Applications Status"
echo "=============================="
echo ""

# Check if applications exist
echo "🔍 Applications in ArgoCD:"
kubectl get applications -n argocd | grep blog-app || echo "  No blog-app applications found"
echo ""

# Check if argocd CLI is available
if command -v argocd &> /dev/null; then
    echo "📋 Detailed Status:"
    echo ""

    for app in blog-app-plain blog-app-kustomize blog-app-helm; do
        if kubectl get application "$app" -n argocd &> /dev/null; then
            echo "=== $app ==="
            argocd app get "$app" --refresh 2>/dev/null | grep -E "Name:|Project:|Server:|Namespace:|Repo:|Path:|Sync Status:|Health Status:" || echo "  Application exists but status unavailable"
            echo ""
        fi
    done
else
    echo "⚠️  argocd CLI not found. Install with:"
    echo "   curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    echo "   chmod +x /usr/local/bin/argocd"
fi

echo ""
echo "🌐 ArgoCD UI: https://argocd.devops-lab.cloud"
echo ""
echo "📱 Deployed Resources:"
echo "  kubectl get pods -n demo-blog      # Plain YAML"
echo "  kubectl get pods -n k-demo-blog    # Kustomize"
echo "  kubectl get pods -n h-demo-blog    # Helm"
