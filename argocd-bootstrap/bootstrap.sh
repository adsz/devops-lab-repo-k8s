#!/bin/bash
# ArgoCD Bootstrap Script
# Aplikuje root app który zarządza całym repo przez ApplicationSets

set -e

echo "🚀 ArgoCD Bootstrap - k8s-local Repository"
echo "=========================================="
echo ""

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo "❌ ArgoCD namespace not found!"
    echo ""
    echo "Please install ArgoCD first:"
    echo "  kubectl apply -k cluster_deployments/argocd/"
    exit 1
fi

echo "✅ ArgoCD namespace found"
echo ""

# Check if ArgoCD is running
if ! kubectl get pods -n argocd | grep -q "Running"; then
    echo "⚠️  ArgoCD pods are not running yet. Waiting..."
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
fi

echo "✅ ArgoCD is running"
echo ""

# Check if root app already exists
if kubectl get application root-applicationsets -n argocd &> /dev/null; then
    echo "⚠️  Root app already exists!"
    echo ""
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Apply root app
echo "📦 Applying root app..."
kubectl apply -f "$(dirname "$0")/root-app.yaml"

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "📊 Monitoring deployment:"
echo "  kubectl get applications -n argocd"
echo "  kubectl get applicationsets -n argocd"
echo ""
echo "🌐 ArgoCD UI:"
echo "  https://argocd.devops-lab.cloud"
echo ""
echo "⏳ Wait ~30 seconds for ApplicationSets to create applications..."
echo ""

# Optional: Wait and show status
read -p "Show live status? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Waiting 30 seconds for ApplicationSets..."
    sleep 30

    echo ""
    echo "=== ApplicationSets ==="
    kubectl get applicationsets -n argocd

    echo ""
    echo "=== Applications ==="
    kubectl get applications -n argocd | head -20

    echo ""
    echo "Run 'kubectl get applications -n argocd' for full list"
fi
