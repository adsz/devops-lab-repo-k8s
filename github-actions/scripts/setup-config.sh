#!/bin/bash
# File: ubuntu-22.04/github-actions/scripts/setup-config.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

echo "=== Kubernetes Disaster Recovery Setup ==="

# Check if secrets.yml exists
if [ ! -f "$CONFIG_DIR/secrets.yml" ]; then
    echo "Creating secrets.yml from template..."
    cp "$CONFIG_DIR/secrets.yml.template" "$CONFIG_DIR/secrets.yml"
    echo "IMPORTANT: Edit $CONFIG_DIR/secrets.yml with your actual credentials"
    echo "The file has been created but contains placeholder values"
fi

# Load configuration
if [ -f "$CONFIG_DIR/config.yml" ]; then
    echo "✓ Configuration file found"
else
    echo "✗ Configuration file not found at $CONFIG_DIR/config.yml"
    exit 1
fi

# Check required tools
echo "Checking required tools..."

if command -v ansible &> /dev/null; then
    echo "✓ Ansible found: $(ansible --version | head -1)"
else
    echo "✗ Ansible not found"
    exit 1
fi

if command -v aws &> /dev/null; then
    echo "✓ AWS CLI found: $(aws --version)"
else
    echo "✗ AWS CLI not found - installing..."
    pip install awscli
fi

if command -v VBoxManage &> /dev/null; then
    echo "✓ VirtualBox found: $(VBoxManage --version)"
else
    echo "⚠ VirtualBox not found - VM snapshot operations will not work"
fi

# Test connectivity to cluster
echo "Testing cluster connectivity..."
if ansible all -i inventory.yml -m ping > /dev/null 2>&1; then
    echo "✓ All nodes reachable"
else
    echo "⚠ Some nodes unreachable - check inventory.yml"
fi

echo "Setup completed successfully!"