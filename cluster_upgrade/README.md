# Kubernetes Cluster Upgrade

This directory contains everything needed to upgrade the Kubernetes cluster from v1.29.15 to v1.34 (latest stable).

## Directory Structure

```
cluster_upgrade/
├── README.md                   # This file
├── UPGRADE-PLAN.md            # Comprehensive upgrade plan and procedures
├── scripts/
│   ├── pre-upgrade-check.sh   # Pre-upgrade health check
│   ├── backup-cluster.sh      # Full cluster backup script
│   └── upgrade-node.sh        # Automated node upgrade script
├── backup/                    # Backup storage (created on first backup)
└── docs/                      # Additional documentation
```

## Quick Start

### 1. Run Pre-Upgrade Check

```bash
cd /repos/devops-lab-new/k8s-local/cluster_upgrade
./scripts/pre-upgrade-check.sh 1.30
```

This validates cluster health and readiness for upgrade.

### 2. Create Backup

```bash
./scripts/backup-cluster.sh pre-upgrade-1.30
```

Creates comprehensive backup including:
- etcd snapshot
- All Kubernetes manifests
- PKI certificates
- Kubeconfig files
- Cluster configurations
- Velero backup (if available)

### 3. Upgrade Control Plane

```bash
./scripts/upgrade-node.sh master k8s-master-1 1.30.6
```

Automates control plane upgrade:
- Drains node
- Upgrades kubeadm
- Applies upgrade
- Upgrades kubelet/kubectl
- Restarts services
- Uncordons node

### 4. Upgrade Worker Nodes

```bash
./scripts/upgrade-node.sh worker k8s-worker-1 1.30.6
./scripts/upgrade-node.sh worker k8s-worker-2 1.30.6
```

Repeat for each worker node sequentially.

### 5. Post-Upgrade Validation

```bash
# Check all nodes
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A | grep -v Running

# Test metrics
kubectl top nodes
kubectl top pods -A

# Create post-upgrade backup
velero backup create post-upgrade-1.30 --wait
```

## Upgrade Path

Kubernetes **does not support skipping minor versions**. You must upgrade sequentially:

```
v1.29.15 → v1.30.x → v1.31.x → v1.32.x → v1.33.x → v1.34.x
```

**Total upgrades required:** 5

## Script Documentation

### pre-upgrade-check.sh

**Purpose:** Validates cluster health before upgrade

**Usage:**
```bash
./scripts/pre-upgrade-check.sh [target-version]
```

**Checks:**
- Node status (all Ready)
- Pod status (all Running/Succeeded)
- PersistentVolumeClaims (no Pending)
- etcd health
- API server health
- Disk space (>20GB recommended)
- DNS resolution
- Certificate expiration
- Metrics server
- Velero backups
- Critical addons (CNI, CoreDNS, kube-proxy)
- Recent events

**Exit Codes:**
- 0: Cluster ready for upgrade
- 1: Critical failures detected
- 2: Warnings detected (proceed with caution)

### backup-cluster.sh

**Purpose:** Creates comprehensive cluster backup

**Usage:**
```bash
./scripts/backup-cluster.sh [backup-name]
```

**Backups:**
- etcd snapshot (critical)
- All Kubernetes resources
- PKI certificates
- Kubeconfig files
- Static pod manifests
- Cluster information
- Velero backup (if available)

**Output:**
- Compressed tar.gz archive
- Location saved in `backup/LATEST_BACKUP.txt`

### upgrade-node.sh

**Purpose:** Automates node upgrade process

**Usage:**
```bash
./scripts/upgrade-node.sh <node-type> <node-name> <target-version>
```

**Examples:**
```bash
# Control plane
./scripts/upgrade-node.sh master k8s-master-1 1.30.6

# Workers
./scripts/upgrade-node.sh worker k8s-worker-1 1.30.6
./scripts/upgrade-node.sh worker k8s-worker-2 1.30.6
```

**Process:**
1. Drain node (evict workloads)
2. Upgrade kubeadm package
3. Apply upgrade (kubeadm upgrade apply/node)
4. Upgrade kubelet and kubectl packages
5. Restart kubelet service
6. Uncordon node
7. Wait for Ready status
8. Verify upgrade

## Important Notes

### Version Selection

For each minor version upgrade, use the latest patch version:

```bash
# Check available versions
apt-cache madison kubeadm | grep 1.30

# Use latest patch (e.g., 1.30.6)
./scripts/upgrade-node.sh master k8s-master-1 1.30.6
```

### Timing Between Upgrades

**Recommended wait time:** 24-48 hours between minor version upgrades

This allows you to:
- Monitor cluster stability
- Validate application functionality
- Detect any compatibility issues
- Create stable backup before next upgrade

### Rollback Procedure

If upgrade fails:

1. **Control Plane Rollback:**
   - Restore etcd from backup
   - Downgrade packages
   - Restart services

2. **Worker Node Rollback:**
   - Downgrade packages
   - Restart kubelet
   - Uncordon node

See `UPGRADE-PLAN.md` for detailed rollback procedures.

## API Deprecations

Before each upgrade, review API deprecations:

- v1.30: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-30
- v1.31: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-31
- v1.32: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-32
- v1.33: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-33
- v1.34: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-34

## Addon Compatibility

Verify compatibility before upgrade:

| Component | Current Version | Compatibility Check |
|-----------|----------------|---------------------|
| Calico | v3.27.3 | https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements |
| Longhorn | - | https://longhorn.io/docs/latest/deploy/important-notes/ |
| MetalLB | - | https://metallb.universe.tf/installation/ |
| cert-manager | - | https://cert-manager.io/docs/installation/supported-releases/ |
| Velero | - | https://velero.io/docs/main/supported-providers/ |

## Troubleshooting

### Node Stuck in NotReady

```bash
# Check kubelet logs
ssh ansible@<node-ip> "sudo journalctl -u kubelet -n 100"

# Restart kubelet
ssh ansible@<node-ip> "sudo systemctl restart kubelet"
```

### Pods Stuck in Terminating

```bash
# Force delete pod
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

### Package Installation Fails

```bash
# Update package lists
ssh ansible@<node-ip> "sudo apt-get update"

# Check available versions
ssh ansible@<node-ip> "apt-cache madison kubeadm"
```

### etcd Health Check Fails

```bash
# Check etcd pod logs
kubectl logs -n kube-system <etcd-pod-name>

# Verify etcd members
kubectl exec -n kube-system <etcd-pod-name> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list
```

## Support

For detailed upgrade procedures and troubleshooting, see:
- `UPGRADE-PLAN.md` - Comprehensive upgrade plan
- Official kubeadm upgrade guide: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- Kubernetes release notes: https://kubernetes.io/docs/setup/release/notes/

## Success Criteria

After each upgrade, verify:
- [ ] All nodes show correct version
- [ ] All pods are Running
- [ ] DNS resolution works
- [ ] Metrics API available
- [ ] Applications functional
- [ ] No errors in control plane logs
- [ ] Velero backup successful

---

**Current Cluster:** v1.29.15
**Target:** v1.34 (latest stable)
**Created:** 2025-11-12
**Last Updated:** 2025-11-12
