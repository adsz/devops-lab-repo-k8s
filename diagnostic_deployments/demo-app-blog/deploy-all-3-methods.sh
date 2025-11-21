#!/bin/bash

echo "=== Deploying Blog App - All 3 Methods ==="
echo ""

cd k8s

# 1. Plain YAML
echo "1️⃣  Deploying Plain YAML..."
kubectl apply -f plain-yaml/
sleep 5

# 2. Kustomize
echo ""
echo "2️⃣  Deploying Kustomize (dev)..."
kubectl apply -k kustomize/overlays/dev/
sleep 5

# 3. Helm
echo ""
echo "3️⃣  Deploying Helm..."
helm install blog-app-helm helm/blog-app/ \
  --namespace h-demo-blog \
  --create-namespace

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "📊 Check status:"
echo "  kubectl get pods -n demo-blog      # Plain YAML"
echo "  kubectl get pods -n k-demo-blog    # Kustomize"
echo "  kubectl get pods -n h-demo-blog    # Helm"
echo ""
echo "🌐 Access URLs:"
echo "  Plain:     http://192.168.0.190:30080 (Frontend) | :30050 (API)"
echo "  Kustomize: http://192.168.0.190:30081 (Frontend) | :30051 (API)"
echo "  Helm:      http://192.168.0.190:30082 (Frontend) | :30052 (API)"
