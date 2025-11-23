#!/bin/bash
#
# Kubernetes Cluster Backup Script
# Creates comprehensive backup before version upgrade
#
# Usage: ./backup-cluster.sh [backup-name]
# Example: ./backup-cluster.sh pre-upgrade-1.30

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKUP_NAME="${1:-pre-upgrade-$(date +%Y%m%d-%H%M%S)}"
BACKUP_DIR="../backup/${BACKUP_NAME}"
MASTER_IP="192.168.0.180"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Kubernetes Cluster Backup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Backup Name: $BACKUP_NAME"
echo "Backup Directory: $BACKUP_DIR"
echo "Timestamp: $(date)"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"/{etcd,manifests,pki,configs,velero}

# 1. Backup etcd
echo -e "\n${BLUE}[1/8]${NC} Backing up etcd..."
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n kube-system "$ETCD_POD" -- sh -c \
  "ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-snapshot.db"

kubectl cp -n kube-system "$ETCD_POD:/tmp/etcd-snapshot.db" "$BACKUP_DIR/etcd/etcd-snapshot.db"
kubectl exec -n kube-system "$ETCD_POD" -- rm /tmp/etcd-snapshot.db

echo -e "${GREEN}✓${NC} etcd snapshot saved"

# 2. Backup all Kubernetes resources
echo -e "\n${BLUE}[2/8]${NC} Backing up Kubernetes resources..."

# All resources
kubectl get all -A -o yaml > "$BACKUP_DIR/manifests/all-resources.yaml"

# Namespaces
kubectl get namespaces -o yaml > "$BACKUP_DIR/manifests/namespaces.yaml"

# ConfigMaps and Secrets
kubectl get configmaps -A -o yaml > "$BACKUP_DIR/manifests/configmaps.yaml"
kubectl get secrets -A -o yaml > "$BACKUP_DIR/manifests/secrets.yaml"

# PersistentVolumes and PVCs
kubectl get pv -o yaml > "$BACKUP_DIR/manifests/persistentvolumes.yaml"
kubectl get pvc -A -o yaml > "$BACKUP_DIR/manifests/persistentvolumeclaims.yaml"

# CRDs
kubectl get crd -o yaml > "$BACKUP_DIR/manifests/crds.yaml"

# StorageClasses
kubectl get storageclass -o yaml > "$BACKUP_DIR/manifests/storageclasses.yaml"

# RBAC
kubectl get clusterroles -o yaml > "$BACKUP_DIR/manifests/clusterroles.yaml"
kubectl get clusterrolebindings -o yaml > "$BACKUP_DIR/manifests/clusterrolebindings.yaml"
kubectl get roles -A -o yaml > "$BACKUP_DIR/manifests/roles.yaml"
kubectl get rolebindings -A -o yaml > "$BACKUP_DIR/manifests/rolebindings.yaml"

echo -e "${GREEN}✓${NC} Kubernetes resources backed up"

# 3. Backup PKI certificates
echo -e "\n${BLUE}[3/8]${NC} Backing up PKI certificates..."
ssh ansible@"$MASTER_IP" "sudo tar czf /tmp/pki-backup.tar.gz -C /etc/kubernetes pki"
scp ansible@"$MASTER_IP":/tmp/pki-backup.tar.gz "$BACKUP_DIR/pki/"
ssh ansible@"$MASTER_IP" "sudo rm /tmp/pki-backup.tar.gz"
echo -e "${GREEN}✓${NC} PKI certificates backed up"

# 4. Backup kubeconfig files
echo -e "\n${BLUE}[4/8]${NC} Backing up kubeconfig files..."
for node in k8s-master-1 k8s-worker-1 k8s-worker-2; do
    if [ "$node" = "k8s-master-1" ]; then
        NODE_IP="192.168.0.180"
    elif [ "$node" = "k8s-worker-1" ]; then
        NODE_IP="192.168.0.190"
    else
        NODE_IP="192.168.0.191"
    fi

    scp ansible@"$NODE_IP":/etc/kubernetes/kubelet.conf "$BACKUP_DIR/configs/kubelet-${node}.conf" 2>/dev/null || echo "  Skipping $node kubelet.conf"
done

# Admin kubeconfig
scp ansible@"$MASTER_IP":/etc/kubernetes/admin.conf "$BACKUP_DIR/configs/admin.conf"

echo -e "${GREEN}✓${NC} Kubeconfig files backed up"

# 5. Backup Kubernetes configs
echo -e "\n${BLUE}[5/8]${NC} Backing up Kubernetes configurations..."
ssh ansible@"$MASTER_IP" "sudo tar czf /tmp/k8s-configs.tar.gz -C /etc/kubernetes manifests"
scp ansible@"$MASTER_IP":/tmp/k8s-configs.tar.gz "$BACKUP_DIR/configs/"
ssh ansible@"$MASTER_IP" "sudo rm /tmp/k8s-configs.tar.gz"
echo -e "${GREEN}✓${NC} Kubernetes configurations backed up"

# 6. Backup cluster info
echo -e "\n${BLUE}[6/8]${NC} Saving cluster information..."
{
    echo "=== Cluster Info ==="
    kubectl cluster-info
    echo ""
    echo "=== Node Versions ==="
    kubectl get nodes -o wide
    echo ""
    echo "=== Component Versions ==="
    kubectl version -o json
    echo ""
    echo "=== Addon Versions ==="
    kubectl get pods -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
} > "$BACKUP_DIR/cluster-info.txt"

echo -e "${GREEN}✓${NC} Cluster information saved"

# 7. Create Velero backup (if available)
echo -e "\n${BLUE}[7/8]${NC} Creating Velero backup..."
if kubectl get deployment velero -n velero &>/dev/null; then
    velero backup create "$BACKUP_NAME" --wait 2>&1 | tee "$BACKUP_DIR/velero/velero-backup.log"

    if [ $? -eq 0 ]; then
        velero backup describe "$BACKUP_NAME" --details > "$BACKUP_DIR/velero/velero-backup-details.txt"
        echo -e "${GREEN}✓${NC} Velero backup created successfully"
    else
        echo -e "${YELLOW}⚠${NC} Velero backup failed (non-critical)"
    fi
else
    echo -e "${YELLOW}⚠${NC} Velero not installed, skipping"
fi

# 8. Create backup manifest
echo -e "\n${BLUE}[8/8]${NC} Creating backup manifest..."
{
    echo "Backup Manifest"
    echo "==============="
    echo ""
    echo "Backup Name: $BACKUP_NAME"
    echo "Created: $(date)"
    echo "Kubernetes Version: $(kubectl version -o json | jq -r '.serverVersion.gitVersion')"
    echo "Cluster: $(kubectl config current-context)"
    echo ""
    echo "Contents:"
    echo "  - etcd snapshot"
    echo "  - All Kubernetes manifests"
    echo "  - PKI certificates"
    echo "  - Kubeconfig files"
    echo "  - Cluster configurations"
    echo "  - Cluster information"
    if kubectl get deployment velero -n velero &>/dev/null; then
        echo "  - Velero backup: $BACKUP_NAME"
    fi
    echo ""
    echo "Backup Size:"
    du -sh "$BACKUP_DIR"
    echo ""
    echo "File Listing:"
    find "$BACKUP_DIR" -type f -exec ls -lh {} \;
} > "$BACKUP_DIR/MANIFEST.txt"

echo -e "${GREEN}✓${NC} Backup manifest created"

# Compress backup
echo -e "\n${BLUE}Compressing backup...${NC}"
tar czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
BACKUP_SIZE=$(du -h "${BACKUP_DIR}.tar.gz" | cut -f1)

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Backup completed successfully${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Backup archive: ${BACKUP_DIR}.tar.gz"
echo "Size: $BACKUP_SIZE"
echo ""
echo "To restore from this backup:"
echo "  1. Extract: tar xzf ${BACKUP_DIR}.tar.gz"
echo "  2. Follow restore procedures in UPGRADE-PLAN.md"
echo ""

# Save backup location
echo "${BACKUP_DIR}.tar.gz" > ../backup/LATEST_BACKUP.txt

exit 0
