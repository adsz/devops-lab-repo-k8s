#!/bin/bash

set -e

echo "=== Blog App Deployment Script ==="
echo ""

# Check if we're running in Kubernetes or Docker Compose
if [ "$1" == "k8s" ]; then
    echo "📦 Building Docker images for Kubernetes..."

    # Build API image
    echo "Building API image..."
    docker build -t blog-api:latest ./src/api

    # Build Frontend image
    echo "Building Frontend image..."
    docker build -t blog-frontend:latest ./src/frontend

    echo ""
    echo "🚀 Deploying to Kubernetes..."

    # Apply manifests using kustomize
    kubectl apply -k ./k8s/

    echo ""
    echo "⏳ Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=blog-db -n demo-blog --timeout=120s || true
    kubectl wait --for=condition=ready pod -l app=blog-cache -n demo-blog --timeout=60s || true
    kubectl wait --for=condition=ready pod -l app=blog-api -n demo-blog --timeout=120s || true
    kubectl wait --for=condition=ready pod -l app=blog-frontend -n demo-blog --timeout=60s || true

    echo ""
    echo "✅ Blog App deployed to Kubernetes!"
    echo ""
    echo "📊 Status:"
    kubectl get pods -n demo-blog
    echo ""
    echo "🌐 Access the application:"
    echo "   Frontend: http://<node-ip>:30080"
    echo ""
    echo "🔍 View logs:"
    echo "   kubectl logs -f deployment/blog-api -n demo-blog"
    echo "   kubectl logs -f deployment/blog-frontend -n demo-blog"
    echo ""

elif [ "$1" == "docker" ] || [ "$1" == "compose" ]; then
    echo "🐳 Deploying with Docker Compose..."

    # Start services
    docker-compose up -d --build

    echo ""
    echo "⏳ Waiting for services to be healthy..."
    sleep 10

    echo ""
    echo "✅ Blog App deployed with Docker Compose!"
    echo ""
    echo "📊 Status:"
    docker-compose ps
    echo ""
    echo "🌐 Access the application:"
    echo "   Frontend: http://localhost:8080"
    echo "   API: http://localhost:5000"
    echo ""
    echo "🔍 View logs:"
    echo "   docker-compose logs -f api"
    echo "   docker-compose logs -f frontend"
    echo ""

else
    echo "Usage: $0 [k8s|docker]"
    echo ""
    echo "Options:"
    echo "  k8s     - Deploy to Kubernetes cluster"
    echo "  docker  - Deploy with Docker Compose"
    echo ""
    exit 1
fi
