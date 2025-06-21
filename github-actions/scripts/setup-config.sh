# File: /repos/devops-lab-new/devops-lab-repo-k8s/github-actions/scripts/setup-config.sh
#!/bin/bash

set -e

echo "=== GitHub Actions Configuration Setup ==="

# Create config directory
mkdir -p github-actions/config

# Check if config files exist
if [ ! -f "github-actions/config/config.yml" ]; then
    echo "Creating github-actions/config/config.yml..."
    # Config file will be created by the artifact above
else
    echo "github-actions/config/config.yml already exists"
fi

if [ ! -f "github-actions/config/secrets.yml" ]; then
    echo "Creating github-actions/config/secrets.yml from template..."
    cp github-actions/config/secrets.yml.template github-actions/config/secrets.yml
    echo "Please edit github-actions/config/secrets.yml with your actual credentials"
else
    echo "github-actions/config/secrets.yml already exists"
fi

# Check if .gitignore is updated
if ! grep -q "github-actions/config/secrets.yml" .gitignore 2>/dev/null; then
    echo "Updating .gitignore..."
    cat >> .gitignore << 'EOF'

# Sensitive configuration files
github-actions/config/secrets.yml
github-actions/config/secrets.yaml
EOF
fi

# Validate current config
echo ""
echo "=== Configuration Validation ==="

if command -v yq &> /dev/null; then
    echo "✓ yq is installed"
    
    if [ -f "github-actions/config/config.yml" ]; then
        echo "✓ github-actions/config/config.yml exists"
        echo "  Load Balancer IP: $(yq '.infrastructure.vm_ips.loadbalancer' github-actions/config/config.yml)"
        echo "  S3 Bucket: $(yq '.backup.s3_bucket' github-actions/config/config.yml)"
    else
        echo "✗ github-actions/config/config.yml missing"
    fi
    
    if [ -f "github-actions/config/secrets.yml" ]; then
        echo "✓ github-actions/config/secrets.yml exists"
        # Don't display sensitive values
        if yq '.aws.access_key_id' github-actions/config/secrets.yml | grep -q "AKIA"; then
            echo "  AWS credentials: configured"
        else
            echo "  AWS credentials: need configuration"
        fi
    else
        echo "✗ github-actions/config/secrets.yml missing"
    fi
else
    echo "Installing yq..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

echo ""
echo "=== Next Steps ==="
echo "1. Edit github-actions/config/config.yml with your infrastructure details"
echo "2. Edit github-actions/config/secrets.yml with your sensitive credentials"
echo "3. Setup GitHub repository secrets (if using GitHub hosted runners):"
echo "   - AWS_ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY" 
echo "   - SLACK_WEBHOOK_URL (optional)"
echo "4. Setup self-hosted runner for local VM access"
echo ""
echo "=== GitHub Secrets Setup Commands ==="
echo "gh secret set AWS_ACCESS_KEY_ID"
echo "gh secret set AWS_SECRET_ACCESS_KEY"
echo "gh secret set SLACK_WEBHOOK_URL"

# Create S3 bucket if AWS CLI is configured
if command -v aws &> /dev/null && aws sts get-caller-identity &>/dev/null; then
    S3_BUCKET=$(yq '.backup.s3_bucket' github-actions/config/config.yml 2>/dev/null || echo "")
    if [ -n "$S3_BUCKET" ] && [ "$S3_BUCKET" != "null" ]; then
        echo ""
        echo "=== S3 Bucket Setup ==="
        if aws s3 ls "s3://$S3_BUCKET" &>/dev/null; then
            echo "✓ S3 bucket $S3_BUCKET exists"
        else
            echo "Creating S3 bucket: $S3_BUCKET"
            aws s3 mb "s3://$S3_BUCKET"
            echo "✓ S3 bucket created"
        fi
    fi
fi

echo ""
echo "Configuration setup completed!"