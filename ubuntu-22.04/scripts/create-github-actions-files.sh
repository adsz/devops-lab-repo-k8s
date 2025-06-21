#!/bin/bash
# File: /repos/devops-lab-new/devops-lab-repo-k8s/create-github-actions-files.sh

set -e

REPO_ROOT="/repos/devops-lab-new/devops-lab-repo-k8s"

echo "=== Creating GitHub Actions Files Structure ==="
echo "Repository root: $REPO_ROOT"

# Ensure we're in the correct directory
cd "$REPO_ROOT"

# Create directories
echo "Creating directories..."
mkdir -p .github/workflows
mkdir -p github-actions/config
mkdir -p github-actions/scripts

# Create empty files with proper paths in comments
echo "Creating empty files with path headers..."

# 1. Main workflow file
echo "Creating .github/workflows/k8s-disaster-recovery.yml..."
cat > .github/workflows/k8s-disaster-recovery.yml << 'EOF'
# File: /repos/devops-lab-new/devops-lab-repo-k8s/.github/workflows/k8s-disaster-recovery.yml
EOF

# 2. Config file
echo "Creating github-actions/config/config.yml..."
cat > github-actions/config/config.yml << 'EOF'
# File: /repos/devops-lab-new/devops-lab-repo-k8s/github-actions/config/config.yml
EOF

# 3. Secrets template
echo "Creating github-actions/config/secrets.yml.template..."
cat > github-actions/config/secrets.yml.template << 'EOF'
# File: /repos/devops-lab-new/devops-lab-repo-k8s/github-actions/config/secrets.yml.template
EOF

# 4. Backup script
echo "Creating github-actions/scripts/backup_k8s_to_s3.sh..."
cat > github-actions/scripts/backup_k8s_to_s3.sh << 'EOF'
# File: /repos/devops-lab-new/devops-lab-repo-k8s/github-actions/scripts/backup_k8s_to_s3.sh
#!/bin/bash
EOF

# 5. Setup script
echo "Creating github-actions/scripts/setup-config.sh..."
cat > github-actions/scripts/setup-config.sh << 'EOF'
# File: /repos/devops-lab-new/devops-lab-repo-k8s/github-actions/scripts/setup-config.sh
#!/bin/bash
EOF

# 6. VM snapshot manager
echo "Creating github-actions/scripts/vm-snapshot-manager.sh..."
cat > github-actions/scripts/vm-snapshot-manager.sh << 'EOF'
# File: /repos/devops-lab-new/devops-lab-repo-k8s/github-actions/scripts/vm-snapshot-manager.sh
#!/bin/bash
EOF

# 7. Update .gitignore
echo "Updating .gitignore..."
if [ -f ".gitignore" ]; then
    if ! grep -q "github-actions/config/secrets.yml" .gitignore; then
        cat >> .gitignore << 'EOF'

# GitHub Actions sensitive configuration files
github-actions/config/secrets.yml
github-actions/config/secrets.yaml
EOF
    fi
else
    cat > .gitignore << 'EOF'
# File: /repos/devops-lab-new/devops-lab-repo-k8s/.gitignore

# GitHub Actions sensitive configuration files
github-actions/config/secrets.yml
github-actions/config/secrets.yaml
EOF
fi

# Make scripts executable
echo "Making scripts executable..."
chmod +x github-actions/scripts/*.sh

# Display created structure
echo ""
echo "=== Created File Structure ==="
tree .github github-actions 2>/dev/null || {
    echo ".github/"
    echo "└── workflows/"
    echo "    └── k8s-disaster-recovery.yml"
    echo ""
    echo "github-actions/"
    echo "├── config/"
    echo "│   ├── config.yml"
    echo "│   └── secrets.yml.template"
    echo "└── scripts/"
    echo "    ├── backup_k8s_to_s3.sh"
    echo "    ├── setup-config.sh"
    echo "    └── vm-snapshot-manager.sh"
}

echo ""
echo "=== Files Created Successfully ==="
echo "✓ .github/workflows/k8s-disaster-recovery.yml"
echo "✓ github-actions/config/config.yml"
echo "✓ github-actions/config/secrets.yml.template"
echo "✓ github-actions/scripts/backup_k8s_to_s3.sh"
echo "✓ github-actions/scripts/setup-config.sh"
echo "✓ github-actions/scripts/vm-snapshot-manager.sh"
echo "✓ .gitignore (updated)"

echo ""
echo "=== Next Steps ==="
echo "1. Copy content from artifacts to each file using the path shown in first line"
echo "2. Edit github-actions/config/config.yml with your configuration"
echo "3. Copy secrets template: cp github-actions/config/secrets.yml.template github-actions/config/secrets.yml"
echo "4. Edit github-actions/config/secrets.yml with your credentials"
echo "5. Run setup script: ./github-actions/scripts/setup-config.sh"

echo ""
echo "File creation completed!"