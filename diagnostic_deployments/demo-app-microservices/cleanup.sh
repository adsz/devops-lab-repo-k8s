#!/bin/bash
# Cleanup Google Microservices Demo

echo "🧹 Cleaning up Google Microservices Demo..."

kubectl delete -f kubernetes-manifests.yaml

echo "✅ Cleanup complete"
