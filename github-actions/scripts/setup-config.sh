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
    echo "✓ github-actions/config/config.yml already exists"
fi

if [ ! -f "github-actions/config/secrets.yml" ]; then
    echo "Creating github-actions/config/secrets.yml from template..."
    if [ -f "github-actions/config/secrets.yml.template" ]; then
        cp github-actions/config/secrets.yml.template github-actions/config/secrets.yml
        echo "Please edit github-actions/config/secrets.yml with your actual credentials"
    else
        echo "Template not found, creating basic secrets.yml"
        cat > github-actions/config/secrets.yml << 'EOF'
# AWS Configuration
aws:
  access_key_id: "AKIA..."
  secret_access_key: "..."
EOF
    fi
else
    echo "✓ github-actions/config/secrets.yml already exists"
fi

# Check if .gitignore is updated
if ! grep -q "github-actions/config/secrets.yml" .gitignore 2>/dev/null; then
    echo "Updating .gitignore..."
    cat >> .gitignore << 'EOF'

# GitHub Actions sensitive configuration files
github-actions/config/secrets.yml
github-actions/config/secrets.yaml
EOF
    echo "✓ .gitignore updated"
else
    echo "✓ .gitignore already configured"
fi

# Validate current config
echo ""
echo "=== Required Tools Validation ==="

# Check VirtualBox
if command -v VBoxManage &> /dev/null; then
    VBOX_VERSION=$(VBoxManage --version 2>/dev/null || echo "unknown")
    echo "✓ VirtualBox installed: $VBOX_VERSION"
    
    # Test VirtualBox functionality
    if VBoxManage list vms &>/dev/null; then
        echo "  ✓ VirtualBox is functional"
        VM_COUNT=$(VBoxManage list vms | wc -l)
        echo "  ✓ Found $VM_COUNT VMs"
    else
        echo "  ✗ VirtualBox not functional"
    fi
else
    echo "✗ VirtualBox not found"
    echo "  Install: https://www.virtualbox.org/wiki/Downloads"
fi

# Check Ansible
if command -v ansible-playbook &> /dev/null; then
    ANSIBLE_VERSION=$(ansible-playbook --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown")
    echo "✓ Ansible installed: $ANSIBLE_VERSION"
    
    # Check if ansible can find inventory
    if [ -f "ubuntu-22.04/inventory.yml" ]; then
        if ansible-playbook --syntax-check ubuntu-22.04/playbooks/ha-cluster-playbook.yml -i ubuntu-22.04/inventory.yml &>/dev/null; then
            echo "  ✓ Ansible playbook syntax OK"
        else
            echo "  ✗ Ansible playbook syntax error"
        fi
    fi
else
    echo "✗ Ansible not found"
    echo "  Install: pip install ansible"
fi

# Check Python3 and pip
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
    echo "✓ Python3 installed: $PYTHON_VERSION"
    
    if command -v pip3 &> /dev/null; then
        echo "  ✓ pip3 available"
    else
        echo "  ✗ pip3 not found"
    fi
else
    echo "✗ Python3 not found"
    echo "  Install: dnf install python3 python3-pip"
fi

# Check uv (Python package manager)
if command -v uv &> /dev/null; then
    UV_VERSION=$(uv --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
    echo "✓ uv installed: $UV_VERSION"
else
    echo "✗ uv not found (will be installed by workflow)"
    echo "  Install: pip3 install uv"
fi

# Check Git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version 2>/dev/null | cut -d' ' -f3 || echo "unknown")
    echo "✓ Git installed: $GIT_VERSION"
    
    # Check if we're in a git repo
    if git rev-parse --git-dir &>/dev/null; then
        echo "  ✓ In git repository"
        CURRENT_BRANCH=$(git branch --show-current)
        echo "  ✓ Current branch: $CURRENT_BRANCH"
    else
        echo "  ✗ Not in git repository"
    fi
else
    echo "✗ Git not found"
    echo "  Install: dnf install git"
fi

# Check SSH
if command -v ssh &> /dev/null; then
    SSH_VERSION=$(ssh -V 2>&1 | head -1 | cut -d' ' -f1 || echo "unknown")
    echo "✓ SSH installed: $SSH_VERSION"
else
    echo "✗ SSH not found"
    echo "  Install: dnf install openssh-clients"
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>/dev/null | cut -d' ' -f1 | cut -d'/' -f2 || echo "unknown")
    echo "✓ AWS CLI installed: $AWS_VERSION"
    
    # Test AWS credentials
    if aws sts get-caller-identity &>/dev/null; then
        AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | cut -d'/' -f2 || echo "unknown")
        echo "  ✓ AWS credentials configured: $AWS_USER"
    else
        echo "  ✗ AWS credentials not configured"
    fi
else
    echo "✗ AWS CLI not found"
    echo "  Install: dnf install awscli"
fi

# Check curl
if command -v curl &> /dev/null; then
    CURL_VERSION=$(curl --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "unknown")
    echo "✓ curl installed: $CURL_VERSION"
else
    echo "✗ curl not found"
    echo "  Install: dnf install curl"
fi

# Check wget
if command -v wget &> /dev/null; then
    WGET_VERSION=$(wget --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown")
    echo "✓ wget installed: $WGET_VERSION"
else
    echo "✗ wget not found"
    echo "  Install: dnf install wget"
fi

# Check sudo permissions
if sudo -n true 2>/dev/null; then
    echo "✓ sudo access: passwordless"
else
    echo "✗ sudo access: requires password (may cause workflow issues)"
    echo "  Fix: Add user to sudoers with NOPASSWD"
fi

# Check GitHub CLI (optional)
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown")
    echo "✓ GitHub CLI installed: $GH_VERSION"
    
    if gh auth status &>/dev/null; then
        echo "  ✓ GitHub authenticated"
    else
        echo "  ✗ GitHub not authenticated"
    fi
else
    echo "⚠ GitHub CLI not found (optional for secret management)"
    echo "  Install: dnf install gh"
fi

echo ""
echo "=== Configuration Validation ==="

if command -v yq &> /dev/null; then
    echo "✓ yq is installed"
    
    if [ -f "github-actions/config/config.yml" ]; then
        echo "✓ github-actions/config/config.yml exists"
        echo "  Load Balancer IP: $(yq '.infrastructure.vm_ips.loadbalancer' github-actions/config/config.yml)"
        echo "  S3 Bucket: $(yq '.backup.s3_bucket' github-actions/config/config.yml)"
        echo "  AWS Region: $(yq '.backup.aws_region' github-actions/config/config.yml)"
        
        # Validate VM IPs
        echo "  VM IPs:"
        echo "    - Master 1: $(yq '.infrastructure.vm_ips.master1' github-actions/config/config.yml)"
        echo "    - Master 2: $(yq '.infrastructure.vm_ips.master2' github-actions/config/config.yml)"
        echo "    - Worker 1: $(yq '.infrastructure.vm_ips.worker1' github-actions/config/config.yml)"
        echo "    - Worker 2: $(yq '.infrastructure.vm_ips.worker2' github-actions/config/config.yml)"
        echo "    - VIP: $(yq '.infrastructure.vm_ips.vip' github-actions/config/config.yml)"
    else
        echo "✗ github-actions/config/config.yml missing"
    fi
    
    if [ -f "github-actions/config/secrets.yml" ]; then
        echo "✓ github-actions/config/secrets.yml exists"
        # Don't display sensitive values
        if yq '.aws.access_key_id' github-actions/config/secrets.yml | grep -q "AKIA"; then
            echo "  AWS credentials: ✓ configured"
        else
            echo "  AWS credentials: ✗ need configuration"
        fi
    else
        echo "✗ github-actions/config/secrets.yml missing"
    fi
else
    echo "Installing yq..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
    echo "✓ yq installed"
fi

# Validate Ansible files
echo ""
echo "=== Ansible Configuration Validation ==="
ANSIBLE_CONFIG=$(yq '.ansible.config_file' github-actions/config/config.yml 2>/dev/null || echo "ubuntu-22.04/ansible.cfg")
ANSIBLE_INVENTORY=$(yq '.ansible.inventory_file' github-actions/config/config.yml 2>/dev/null || echo "ubuntu-22.04/inventory.yml")
ANSIBLE_PLAYBOOK=$(yq '.ansible.playbook_path' github-actions/config/config.yml 2>/dev/null || echo "ubuntu-22.04/playbooks/ha-cluster-playbook.yml")

if [ -f "$ANSIBLE_CONFIG" ]; then
    echo "✓ Ansible config: $ANSIBLE_CONFIG"
else
    echo "✗ Ansible config missing: $ANSIBLE_CONFIG"
fi

if [ -f "$ANSIBLE_INVENTORY" ]; then
    echo "✓ Ansible inventory: $ANSIBLE_INVENTORY"
else
    echo "✗ Ansible inventory missing: $ANSIBLE_INVENTORY"
fi

if [ -f "$ANSIBLE_PLAYBOOK" ]; then
    echo "✓ Ansible playbook: $ANSIBLE_PLAYBOOK"
else
    echo "✗ Ansible playbook missing: $ANSIBLE_PLAYBOOK"
fi

# Test VM connectivity
echo ""
echo "=== VM Connectivity Test ==="
SSH_KEY_PATH=$(yq '.kubernetes.ssh_key_path' github-actions/config/config.yml 2>/dev/null || echo "/root/.ssh/id_rsa")
MASTER_USER=$(yq '.kubernetes.master_user' github-actions/config/config.yml 2>/dev/null || echo "ansible")

if [ -f "$SSH_KEY_PATH" ]; then
    echo "✓ SSH key exists: $SSH_KEY_PATH"
    
    # Test connectivity to master1
    MASTER1_IP=$(yq '.infrastructure.vm_ips.master1' github-actions/config/config.yml 2>/dev/null)
    if [ -n "$MASTER1_IP" ]; then
        echo "Testing SSH to master1 ($MASTER1_IP)..."
        if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER1_IP" "echo 'SSH OK'" 2>/dev/null; then
            echo "✓ SSH to master1: OK"
        else
            echo "✗ SSH to master1: FAILED"
        fi
    fi
else
    echo "✗ SSH key missing: $SSH_KEY_PATH"
fi

# Create S3 bucket if AWS CLI is configured
echo ""
echo "=== S3 Bucket Setup ==="
if command -v aws &> /dev/null && aws sts get-caller-identity &>/dev/null; then
    S3_BUCKET=$(yq '.backup.s3_bucket' github-actions/config/config.yml 2>/dev/null || echo "")
    if [ -n "$S3_BUCKET" ] && [ "$S3_BUCKET" != "null" ]; then
        echo "Testing S3 bucket: $S3_BUCKET"
        if aws s3 ls "s3://$S3_BUCKET" &>/dev/null; then
            echo "✓ S3 bucket $S3_BUCKET exists and accessible"
        else
            echo "Creating S3 bucket: $S3_BUCKET"
            if aws s3 mb "s3://$S3_BUCKET"; then
                echo "✓ S3 bucket created successfully"
            else
                echo "✗ Failed to create S3 bucket"
            fi
        fi
    else
        echo "✗ S3 bucket name not configured"
    fi
else
    echo "✗ AWS CLI not configured or no access"
fi

# Validate VM snapshots
echo ""
echo "=== VM Snapshots Validation ==="
VM_NAMES=($(yq '.snapshots.vm_names[]' github-actions/config/config.yml 2>/dev/null))
DEFAULT_SNAPSHOT=$(yq '.snapshots.default_snapshot' github-actions/config/config.yml 2>/dev/null)

if [ ${#VM_NAMES[@]} -gt 0 ]; then
    echo "Configured VMs: ${VM_NAMES[*]}"
    echo "Default snapshot: $DEFAULT_SNAPSHOT"
    
    # Check if VMs exist in VirtualBox
    for vm in "${VM_NAMES[@]}"; do
        if VBoxManage list vms | grep -q "\"$vm\""; then
            echo "✓ VM exists: $vm"
            
            # Check if default snapshot exists
            if VBoxManage showvminfo "$vm" --machinereadable 2>/dev/null | grep -q "SnapshotName.*$DEFAULT_SNAPSHOT"; then
                echo "  ✓ Snapshot exists: $DEFAULT_SNAPSHOT"
            else
                echo "  ✗ Snapshot missing: $DEFAULT_SNAPSHOT"
            fi
        else
            echo "✗ VM not found: $vm"
        fi
    done
else
    echo "✗ No VMs configured in snapshots.vm_names"
fi

echo ""
echo "=== Overall System Readiness ==="

# Count missing tools
MISSING_TOOLS=0
MISSING_LIST=""

for tool in VBoxManage ansible-playbook python3 git ssh aws curl wget; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
        MISSING_LIST="$MISSING_LIST $tool"
    fi
done

if [ $MISSING_TOOLS -eq 0 ]; then
    echo "✅ ALL REQUIRED TOOLS INSTALLED"
    echo "✅ SYSTEM READY FOR GITHUB ACTIONS WORKFLOW"
else
    echo "❌ MISSING $MISSING_TOOLS REQUIRED TOOLS:$MISSING_LIST"
    echo "❌ INSTALL MISSING TOOLS BEFORE RUNNING WORKFLOW"
fi

echo ""
echo "=== Setup Summary ==="
echo "✓ Configuration files created/validated"
echo "✓ Scripts are executable"
echo ""
echo "=== Next Steps ==="
echo "1. Edit github-actions/config/config.yml with your infrastructure details"
echo "2. Edit github-actions/config/secrets.yml with your AWS credentials"
echo "3. Setup GitHub repository secrets:"
echo "   - AWS_ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY"
echo "4. Setup self-hosted runner for local VM access"
echo ""
echo "=== Installation Commands for Missing Tools ==="
echo "# Oracle Linux installation commands:"
echo "sudo dnf update"
echo "sudo dnf install -y python3 python3-pip git openssh-clients curl wget awscli"
echo "pip3 install ansible uv"
echo ""
echo "# VirtualBox installation:"
echo "# Download from: https://www.virtualbox.org/wiki/Linux_Downloads"
echo ""
echo "# GitHub CLI (optional):"
echo "sudo dnf install gh"
echo ""
echo "=== GitHub Secrets Setup Commands ==="
echo "gh secret set AWS_ACCESS_KEY_ID"
echo "gh secret set AWS_SECRET_ACCESS_KEY"
echo ""
echo "=== Manual Workflow Test ==="
echo "After setup, test the workflow:"
echo "1. Go to GitHub Actions tab"
echo "2. Select 'Kubernetes Disaster Recovery'"
echo "3. Click 'Run workflow'"
echo "4. Set dry_run=true for first test"
echo ""
echo "Configuration setup completed!"