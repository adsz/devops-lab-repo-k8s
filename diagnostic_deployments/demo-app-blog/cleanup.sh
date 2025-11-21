#!/bin/bash

set -e

echo "=== Blog App Cleanup Script ==="
echo ""

# Check if we're cleaning up Kubernetes or Docker Compose
if [ "$1" == "k8s" ]; then
    echo "🧹 Cleaning up Kubernetes resources..."

    # Delete namespace (this will delete all resources in it)
    kubectl delete namespace demo-blog --ignore-not-found=true

    echo ""
    echo "⏳ Waiting for namespace to be deleted..."
    kubectl wait --for=delete namespace/demo-blog --timeout=120s || true

    echo ""
    echo "✅ Kubernetes cleanup complete!"

elif [ "$1" == "docker" ] || [ "$1" == "compose" ]; then
    echo "🧹 Cleaning up Docker Compose resources..."

    # Stop and remove containers
    docker-compose down -v

    # Remove built images (optional)
    read -p "Remove built Docker images? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker rmi blog-api:latest blog-frontend:latest 2>/dev/null || true
        echo "✅ Docker images removed"
    fi

    echo ""
    echo "✅ Docker Compose cleanup complete!"

elif [ "$1" == "all" ]; then
    echo "🧹 Cleaning up all deployments..."

    # Kubernetes cleanup
    kubectl delete namespace demo-blog --ignore-not-found=true || true

    # Docker Compose cleanup
    docker-compose down -v 2>/dev/null || true

    # Remove images
    read -p "Remove built Docker images? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker rmi blog-api:latest blog-frontend:latest 2>/dev/null || true
    fi

    echo ""
    echo "✅ Complete cleanup done!"

else
    echo "Usage: $0 [k8s|docker|all]"
    echo ""
    echo "Options:"
    echo "  k8s     - Clean up Kubernetes deployment"
    echo "  docker  - Clean up Docker Compose deployment"
    echo "  all     - Clean up both K8s and Docker Compose"
    echo ""
    exit 1
fi
