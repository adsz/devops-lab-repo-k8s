#!/bin/bash
# Cleanup Sock Shop Demo

echo "🧹 Cleaning up Sock Shop..."

kubectl delete -f kubernetes-manifests.yaml
kubectl delete namespace sock-shop

echo "✅ Cleanup complete"
