# Kubernetes Cluster Upgrade Plan: v1.29.15 → v1.34

## Current State

**Date:** 2025-11-12
**Current Version:** v1.29.15
**Target Version:** v1.34 (latest stable)
**Cluster Type:** kubeadm-based, 3-node cluster

**Nodes:**
- k8s-master-1: v1.29.15 (192.168.0.180) - Control Plane
- k8s-worker-1: v1.29.15 (192.168.0.190) - Worker
- k8s-worker-2: v1.29.15 (192.168.0.191) - Worker

**Container Runtime:** containerd 1.7.27
**CNI:** Calico v3.27.3
**Cluster Age:** 153 days

---

## Upgrade Path (Sequential)

Kubernetes **DOES NOT support skipping minor versions**. Must upgrade one version at a time:

```
v1.29.15 → v1.30.x → v1.31.x → v1.32.x → v1.33.x → v1.34.x
```

**Total Upgrades Required:** 5 consecutive upgrades

---

## Version Support Matrix

| Version | Release Date | End of Support | Status |
|---------|--------------|----------------|--------|
| v1.29   | Dec 2023     | Feb 2025       | ⚠️ Near EOL |
| v1.30   | Apr 2024     | Jun 2025       | Supported |
| v1.31   | Aug 2024     | Oct 2025       | Supported |
| v1.32   | Dec 2024     | Feb 2026       | Supported |
| v1.33   | Apr 2025     | Jun 2026       | Supported |
| v1.34   | Aug 2025     | Oct 2026       | ✅ Latest Stable |

---

## Pre-Upgrade Requirements

### 1. Backup Checklist

- [ ] Full etcd backup
- [ ] All Kubernetes manifests (`kubectl get all -A -o yaml`)
- [ ] Velero cluster backup
- [ ] Custom Resource Definitions (CRDs)
- [ ] ConfigMaps and Secrets
- [ ] PersistentVolumes data
- [ ] Certificate files (`/etc/kubernetes/pki/`)
- [ ] Node kubeconfig files

### 2. Compatibility Verification

- [ ] Check CNI plugin compatibility (Calico)
- [ ] Verify all addons compatibility (MetalLB, cert-manager, Longhorn, etc.)
- [ ] Review API deprecations for target version
- [ ] Test application compatibility with new K8s version
- [ ] Verify containerd version compatibility
- [ ] Check Helm charts compatibility

### 3. Cluster Health Check

- [ ] All nodes are Ready
- [ ] All pods are Running
- [ ] No pending PersistentVolumeClaims
- [ ] Cluster networking functional
- [ ] DNS resolution working
- [ ] Sufficient disk space on all nodes (>20GB free)
- [ ] Recent Velero backup completed successfully

---

## Upgrade Strategy

### Option A: Rolling Upgrade (Recommended for Production)
- **Downtime:** Minimal (workload disruption during node drain)
- **Rollback:** Complex but possible
- **Duration:** ~2-3 hours per version
- **Risk:** Low

### Option B: Blue-Green Cluster (Safest)
- **Downtime:** Zero (with proper DNS/LB cutover)
- **Rollback:** Easy (switch back to old cluster)
- **Duration:** ~4-6 hours per version
- **Risk:** Very Low

### Option C: In-Place Upgrade (For Lab/Dev)
- **Downtime:** High (full cluster unavailable)
- **Rollback:** Requires restore from backup
- **Duration:** ~1-2 hours per version
- **Risk:** Medium-High

**Chosen Strategy:** Option A (Rolling Upgrade)

---

## Upgrade Procedure (Per Version)

### Phase 1: Pre-Upgrade

```bash
# 1. Create backup
./cluster_upgrade/scripts/backup-cluster.sh

# 2. Verify cluster health
./cluster_upgrade/scripts/pre-upgrade-check.sh

# 3. Review release notes
# https://kubernetes.io/docs/setup/release/notes/
```

### Phase 2: Control Plane Upgrade

```bash
# 1. Upgrade kubeadm on master
ssh ansible@192.168.0.180
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.30.x-1.1  # Replace x with patch version
sudo apt-mark hold kubeadm

# 2. Plan upgrade
sudo kubeadm upgrade plan

# 3. Drain control plane (from ol01)
kubectl drain k8s-master-1 --ignore-daemonsets --delete-emptydir-data

# 4. Apply upgrade (on master)
sudo kubeadm upgrade apply v1.30.x

# 5. Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.30.x-1.1 kubectl=1.30.x-1.1
sudo apt-mark hold kubelet kubectl

# 6. Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 7. Uncordon master (from ol01)
kubectl uncordon k8s-master-1

# 8. Verify control plane
kubectl get nodes
kubectl version
```

### Phase 3: Worker Node Upgrade (Repeat for each worker)

```bash
# For k8s-worker-1 (192.168.0.190)

# 1. Drain node (from ol01)
kubectl drain k8s-worker-1 --ignore-daemonsets --delete-emptydir-data

# 2. Upgrade kubeadm (on worker)
ssh ansible@192.168.0.190
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.30.x-1.1
sudo apt-mark hold kubeadm

# 3. Upgrade node
sudo kubeadm upgrade node

# 4. Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.30.x-1.1 kubectl=1.30.x-1.1
sudo apt-mark hold kubelet kubectl

# 5. Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 6. Uncordon node (from ol01)
kubectl uncordon k8s-worker-1

# 7. Verify node
kubectl get node k8s-worker-1
```

### Phase 4: Post-Upgrade Validation

```bash
# 1. Verify all nodes
kubectl get nodes -o wide

# 2. Verify all pods
kubectl get pods -A | grep -v Running

# 3. Check cluster info
kubectl cluster-info
kubectl version

# 4. Test workloads
./cluster_upgrade/scripts/post-upgrade-test.sh

# 5. Verify addons
kubectl get pods -n kube-system
kubectl get pods -n metallb-system
kubectl get pods -n longhorn-system

# 6. Create Velero backup
velero backup create post-upgrade-v1.30 --wait
```

---

## Rollback Plan

### If Upgrade Fails on Control Plane:

```bash
# 1. Stop kubelet
sudo systemctl stop kubelet

# 2. Restore etcd from backup
sudo ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore

# 3. Update etcd manifest to use restored data
sudo vi /etc/kubernetes/manifests/etcd.yaml
# Change hostPath to /var/lib/etcd-restore

# 4. Restart kubelet
sudo systemctl start kubelet

# 5. Verify cluster
kubectl get nodes
```

### If Upgrade Fails on Worker:

```bash
# 1. Downgrade packages
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get install -y kubeadm=1.29.15-1.1 kubelet=1.29.15-1.1 kubectl=1.29.15-1.1
sudo apt-mark hold kubeadm kubelet kubectl

# 2. Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 3. Uncordon node
kubectl uncordon <node-name>
```

---

## Timeline Estimate

| Phase | Version | Estimated Time | Cumulative |
|-------|---------|----------------|------------|
| Prep | - | 2 hours | 2h |
| Upgrade 1 | v1.29 → v1.30 | 3 hours | 5h |
| Validation 1 | - | 1 hour | 6h |
| Upgrade 2 | v1.30 → v1.31 | 3 hours | 9h |
| Validation 2 | - | 1 hour | 10h |
| Upgrade 3 | v1.31 → v1.32 | 3 hours | 13h |
| Validation 3 | - | 1 hour | 14h |
| Upgrade 4 | v1.32 → v1.33 | 3 hours | 17h |
| Validation 4 | - | 1 hour | 18h |
| Upgrade 5 | v1.33 → v1.34 | 3 hours | 21h |
| Final Testing | - | 2 hours | 23h |

**Total Estimated Time:** ~23-25 hours (can be split across multiple days)

---

## API Deprecations to Review

### v1.30 Changes
- Check: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-30

### v1.31 Changes
- Check: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-31

### v1.32 Changes
- Check: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-32

### v1.33 Changes
- Check: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-33

### v1.34 Changes
- Check: https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-34

---

## Known Issues and Mitigations

### Issue 1: CNI Plugin Compatibility
**Risk:** Calico v3.27.3 may need upgrade
**Mitigation:** Check Calico compatibility matrix before each K8s upgrade
**Action:** https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements

### Issue 2: Longhorn Storage
**Risk:** Volume operations may fail during upgrade
**Mitigation:** Ensure no volume attach/detach operations during upgrade
**Action:** Set Longhorn to maintenance mode before drain

### Issue 3: MetalLB Speaker Interruption
**Risk:** Service IPs may be temporarily unavailable
**Mitigation:** MetalLB speaker runs as DaemonSet (graceful failover)
**Action:** Monitor service endpoints during upgrade

### Issue 4: Prometheus/Monitoring Gaps
**Risk:** Metrics collection gaps during pod eviction
**Mitigation:** Expected behavior, data resumes after uncordon
**Action:** Document upgrade windows in monitoring

---

## Communication Plan

### Before Upgrade
- [ ] Notify team of planned upgrade window
- [ ] Document current cluster state
- [ ] Schedule upgrade during low-traffic period

### During Upgrade
- [ ] Update status in team channel
- [ ] Document any issues encountered
- [ ] Keep team informed of progress

### After Upgrade
- [ ] Confirm successful upgrade
- [ ] Document lessons learned
- [ ] Update cluster documentation

---

## Success Criteria

- [ ] All nodes running target version
- [ ] All pods in Running state (except completed jobs)
- [ ] All services accessible
- [ ] DNS resolution functional
- [ ] Metrics API available (`kubectl top nodes`)
- [ ] Velero backup completed successfully
- [ ] No errors in control plane logs
- [ ] Application workloads functional
- [ ] No performance degradation

---

## References

- Official kubeadm upgrade guide: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- Kubernetes release notes: https://kubernetes.io/docs/setup/release/notes/
- Calico compatibility: https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
- Longhorn support matrix: https://longhorn.io/docs/latest/deploy/important-notes/
- Version skew policy: https://kubernetes.io/releases/version-skew-policy/

---

## Next Steps

1. Review this plan with team
2. Schedule upgrade window
3. Run pre-upgrade checklist
4. Create comprehensive backups
5. Begin with v1.29 → v1.30 upgrade
6. Validate and stabilize before next upgrade
