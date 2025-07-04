# File: /repos/devops-lab-new/devops-lab-repo-k8s/github-actions/scripts/backup_k8s_to_s3.sh
#!/bin/bash

set -e

# Load configuration from config files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/config.yml"
SECRETS_FILE="$SCRIPT_DIR/../config/secrets.yml"

# Check if yq is available
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required. Install with: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
    exit 1
fi

# Load configuration
S3_BUCKET=$(yq '.backup.s3_bucket' "$CONFIG_FILE")
MASTER_IP=$(yq '.infrastructure.vm_ips.master1' "$CONFIG_FILE")
MASTER_USER=$(yq '.kubernetes.master_user' "$CONFIG_FILE")
SSH_KEY_PATH=$(yq '.kubernetes.ssh_key_path' "$CONFIG_FILE")
KUBECONFIG_PATH=$(yq '.kubernetes.kubeconfig_path' "$CONFIG_FILE")

# Override S3_BUCKET if set as environment variable
S3_BUCKET="${S3_BUCKET:-$(yq '.backup.s3_bucket' "$CONFIG_FILE")}"
BACKUP_NAME="k8s-backup-$(date +%Y%m%d-%H%M%S)"

echo "=== Kubernetes Backup to S3 ==="
echo "Backup name: $BACKUP_NAME"
echo "S3 bucket: $S3_BUCKET"
echo "Master IP: $MASTER_IP"
echo "Master user: $MASTER_USER"

# Create backup directory
mkdir -p $BACKUP_NAME

# Test cluster connectivity
echo "Testing cluster connectivity..."
if ! ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 "$MASTER_USER@$MASTER_IP" "kubectl cluster-info" &>/dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "Cluster accessible, starting backup..."

# Create backup script for remote execution
cat > /tmp/remote-backup.sh << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR=$1
export KUBECONFIG="/home/ansible/.kube/config"

echo "Creating backup directory: $BACKUP_DIR"
mkdir -p $BACKUP_DIR

# Function to backup namespace
backup_namespace() {
    local ns=$1
    local backup_dir=$2
    
    echo "Backing up namespace: $ns"
    mkdir -p $backup_dir/$ns
    
    # Get all resources in namespace
    if [[ "$ns" == "kube-system" ]] || [[ "$ns" == "kube-public" ]] || [[ "$ns" == "kube-node-lease" ]]; then
        # System namespaces - backup only essential resources
        kubectl get deployments,services,configmaps,secrets -n $ns -o yaml > $backup_dir/$ns/essential.yaml 2>/dev/null || true
    else
        # Application namespaces - backup everything
        kubectl get all,configmaps,secrets,pv,pvc,ingress,networkpolicies -n $ns -o yaml > $backup_dir/$ns/all-resources.yaml 2>/dev/null || true
    fi
    
    # Create namespace manifest
    kubectl get namespace $ns -o yaml > $backup_dir/$ns/namespace.yaml 2>/dev/null || true
}

# Backup all namespaces
echo "Getting list of namespaces..."
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
    backup_namespace $ns $BACKUP_DIR
done

# Backup cluster-wide resources
echo "Backing up cluster-wide resources..."
kubectl get nodes -o yaml > $BACKUP_DIR/nodes.yaml 2>/dev/null || true
kubectl get clusterroles -o yaml > $BACKUP_DIR/clusterroles.yaml 2>/dev/null || true
kubectl get clusterrolebindings -o yaml > $BACKUP_DIR/clusterrolebindings.yaml 2>/dev/null || true
kubectl get storageclasses -o yaml > $BACKUP_DIR/storageclasses.yaml 2>/dev/null || true
kubectl get customresourcedefinitions -o yaml > $BACKUP_DIR/crds.yaml 2>/dev/null || true

# Backup persistent volumes separately
echo "Backing up persistent volumes..."
kubectl get pv -o yaml > $BACKUP_DIR/persistent-volumes.yaml 2>/dev/null || true

# Create cluster info
echo "Creating cluster info..."
kubectl cluster-info > $BACKUP_DIR/cluster-info.txt 2>/dev/null || true
kubectl version > $BACKUP_DIR/version.txt 2>/dev/null || true
kubectl get nodes -o wide > $BACKUP_DIR/nodes-status.txt 2>/dev/null || true

# Create restore script
cat > $BACKUP_DIR/restore.sh << 'RESTORE_EOF'
#!/bin/bash
# Kubernetes Restore Script
set -e

echo "=== Kubernetes Restore Script ==="
echo "Starting restore process..."

# Function to restore namespace
restore_namespace() {
    local ns=$1
    local backup_dir=$2
    
    if [[ "$ns" =~ ^(kube-|default$) ]]; then
        echo "Skipping system namespace: $ns"
        return
    fi
    
    echo "Restoring namespace: $ns"
    
    # Create namespace first
    if [ -f "$backup_dir/$ns/namespace.yaml" ]; then
        kubectl apply -f $backup_dir/$ns/namespace.yaml || true
    else
        kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f - || true
    fi
    
    # Wait for namespace to be ready
    sleep 2
    
    # Restore resources
    if [ -f "$backup_dir/$ns/all-resources.yaml" ]; then
        echo "  Restoring all resources for $ns..."
        kubectl apply -f $backup_dir/$ns/all-resources.yaml || true
    fi
}

# Restore cluster-wide resources first
echo "Restoring cluster-wide resources..."
[ -f "storageclasses.yaml" ] && kubectl apply -f storageclasses.yaml || true
[ -f "crds.yaml" ] && kubectl apply -f crds.yaml || true

# Wait for CRDs to be established
sleep 5

# Restore persistent volumes
echo "Restoring persistent volumes..."
[ -f "persistent-volumes.yaml" ] && kubectl apply -f persistent-volumes.yaml || true

# Restore namespaces (skip system namespaces)
for ns_dir in */; do
    ns=$(basename "$ns_dir")
    if [[ ! "$ns" =~ ^(kube-|default$) ]]; then
        restore_namespace $ns .
    fi
done

# Restore default namespace applications
if [ -f "default/all-resources.yaml" ]; then
    echo "Restoring default namespace applications..."
    kubectl apply -f default/all-resources.yaml || true
fi

echo "Waiting for pods to start..."
sleep 30

echo "=== Restore Summary ==="
kubectl get nodes
echo ""
kubectl get pods --all-namespaces
echo ""
echo "Restore completed successfully!"
RESTORE_EOF

chmod +x $BACKUP_DIR/restore.sh

# Create backup metadata
cat > $BACKUP_DIR/backup-info.json << METADATA_EOF
{
    "backup_date": "$(date -Iseconds)",
    "cluster_version": "$(kubectl version --short 2>/dev/null || echo 'unknown')",
    "node_count": $(kubectl get nodes --no-headers | wc -l),
    "namespace_count": $(kubectl get namespaces --no-headers | wc -l),
    "backup_script_version": "1.0"
}
METADATA_EOF

echo "Backup completed: $BACKUP_DIR"
ls -la $BACKUP_DIR/
EOF

# Copy and execute backup script on master node
scp -i "$SSH_KEY_PATH" /tmp/remote-backup.sh "$MASTER_USER@$MASTER_IP:/tmp/"
ssh -i "$SSH_KEY_PATH" "$MASTER_USER@$MASTER_IP" "bash /tmp/remote-backup.sh /tmp/$BACKUP_NAME"

# Download backup from master node
echo "Downloading backup from master node..."
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -r "$MASTER_USER@$MASTER_IP:/tmp/$BACKUP_NAME" ./

# Upload to S3
echo "Uploading backup to S3..."
if command -v aws &> /dev/null; then
    aws s3 cp "$BACKUP_NAME" "s3://$S3_BUCKET/backups/$BACKUP_NAME/" --recursive
    echo "Backup uploaded to: s3://$S3_BUCKET/backups/$BACKUP_NAME/"
    
    # Create latest backup pointer
    echo "$BACKUP_NAME" > latest-backup.txt
    aws s3 cp latest-backup.txt "s3://$S3_BUCKET/latest-backup.txt"
    
    # List recent backups
    echo "Recent backups in S3:"
    aws s3 ls "s3://$S3_BUCKET/backups/" | tail -5
else
    echo "AWS CLI not found, backup saved locally only: $BACKUP_NAME"
fi

# Cleanup remote backup
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$MASTER_USER@$MASTER_IP" "rm -rf /tmp/$BACKUP_NAME /tmp/remote-backup.sh"

echo "=== Backup Summary ==="
echo "Local backup: $PWD/$BACKUP_NAME"
if command -v aws &> /dev/null; then
    echo "S3 backup: s3://$S3_BUCKET/backups/$BACKUP_NAME/"
fi
echo "To restore: cd $BACKUP_NAME && bash restore.sh"
