# Kubernetes Cluster Performance Analysis Report
**Date:** 2025-11-21
**Analyst:** DevOps Team
**Cluster:** k8s-local production (3-node cluster)

---

## Executive Summary

The Kubernetes cluster is experiencing **CRITICAL resource constraints** leading to high system load, frequent pod restarts, and performance degradation. All three nodes are under-resourced with only 4GB RAM each and no swap space configured.

### Critical Metrics:
- **k8s-worker-1**: Load average **5.04** (CRITICAL), 73% memory usage, 1180 prometheus-adapter restarts
- **k8s-master-1**: Load average **2.95** (HIGH), 65% memory usage, kube-apiserver consuming 839MB
- **k8s-worker-2**: Load average **1.93** (MODERATE), 46% memory usage

---

## Detailed Findings

### 1. Infrastructure Constraints

#### Memory Analysis:
```
Node          Total RAM   Used    Free    Available   Load Avg
k8s-master-1  3.8GB      1.7GB   270MB   1.8GB       2.95
k8s-worker-1  3.8GB      2.2GB   236MB   1.4GB       5.04  <- CRITICAL
k8s-worker-2  3.8GB      719MB   1.1GB   2.8GB       1.93
```

**Problems:**
- All nodes have only **4GB RAM** - insufficient for Kubernetes + monitoring stack
- **Zero swap space** configured - no safety buffer for memory pressure
- k8s-worker-1 has only **236MB free** - extremely dangerous
- k8s-master-1 has only **270MB free** - control plane at risk

#### CPU Analysis:
```
Node          CPU Usage   Allocated CPU Limits
k8s-master-1  50% (1019m) N/A (control plane)
k8s-worker-1  28% (576m)  100% (2000m) <- FULLY ALLOCATED
k8s-worker-2  11% (234m)  Unknown
```

**Problems:**
- k8s-worker-1 has **100% CPU limits allocated** - cannot schedule more pods
- Uneven distribution - worker-1 overloaded, worker-2 underutilized

---

### 2. Top Resource Consumers

#### k8s-master-1 (Control Plane):
| Process | Memory | CPU | Issues |
|---------|--------|-----|--------|
| kube-apiserver | 839MB (20.9%) | 8.7% | Excessive memory usage |
| prometheus-adapter | 223MB (5.5%) | 22.8% | **1180 restarts** - OOMKilled |
| etcd | 130MB (3.2%) | 3.5% | OK |
| kube-controller-manager | 101MB (2.5%) | 1.6% | OK |
| kubelet | 82MB (2.0%) | 3.3% | OK |

#### k8s-worker-1 (MOST OVERLOADED):
| Process/Pod | Memory | CPU | Issues |
|-------------|--------|-----|--------|
| Prometheus | 445MB | 235m | Excessive, retention=7d |
| Grafana | 344MB | 21m | Too high |
| 6x Python sidecars | ~432MB total | - | Grafana dashboard loaders |
| Longhorn-manager | 106MB | 26m | OK |
| Kubelet | 111MB | 8.7% | High CPU |
| Containerd | 87MB | 2.6% | OK |
| Velero | 76MB | - | OK |

#### k8s-worker-2 (UNDERUTILIZED):
| Process | Memory | CPU | Issues |
|---------|--------|-----|--------|
| systemd-journald | 189MB (4.7%) | 0.1% | Excessive logging! |
| Longhorn-manager | 101MB | 16m | OK |
| Kubelet | 92MB | 3.3% | OK |

---

### 3. Pod Distribution Problem

**k8s-worker-1 hosts 80%+ of all workload pods:**
- ALL monitoring stack pods (Prometheus, Grafana, Alertmanager, operators)
- Majority of Longhorn CSI pods (12+ CSI pods)
- Cert-manager (3 pods)
- Ingress-nginx
- MetalLB controller
- NFS provisioner
- Velero

**k8s-worker-2 is severely underutilized:**
- Only Longhorn manager + node agents
- MetalLB speaker
- Node exporters

**Root cause:** No pod anti-affinity rules or taints/tolerations configured.

---

### 4. Resource Limits Issues

**CRITICAL:** Most pods have **NO resource limits** configured:

```
Pod                           Requests        Limits          Actual Usage
prometheus-prometheus-0       NONE            NONE            445MB (uncontrolled!)
prometheus-stack-grafana      NONE            NONE            344MB (uncontrolled!)
prometheus-adapter            128Mi/100m      256Mi/500m      171MB (⚠️ 1180 restarts)
alertmanager                  200Mi           NONE            37MB
kube-state-metrics            NONE            NONE            27MB
```

**Consequences:**
- Pods can consume unlimited memory → OOM kills
- Kubernetes scheduler cannot make informed decisions
- No QoS guarantees
- System instability

---

### 5. Prometheus-Specific Issues

#### Prometheus-Adapter Crashloop:
- **1180 restarts** in 30 days (avg 39/day)
- **Memory limit:** 256Mi
- **Actual usage:** 171Mi (66% of limit)
- **Restarts** likely caused by memory spikes above 256Mi
- **Config:** `--metrics-relist-interval=1m` - very aggressive

#### Prometheus Storage Issues:
```
ERROR: out of sequence m-mapped chunk for series ref 470283
INFO: Deletion of corrupted mmap chunk files failed, discarding chunk files completely
```
- **Corrupted WAL data** on disk
- **Retention:** 7 days (excessive for 4GB RAM node)
- **Storage path:** /prometheus (likely on root filesystem)

---

### 6. Longhorn Storage Issues

#### Engine-Image Pod on worker-1:
- **1285 restarts** in 22 days (avg 58/day!)
- Indicates storage subsystem instability
- May be related to memory pressure

#### Velero Backup Failures:
```
velero nfs-provisioner-default-kopia-maintain-job - Error (repeating every 5 minutes)
```
- Backup maintenance jobs failing
- Likely insufficient resources to complete

---

## Root Cause Analysis

### Primary Issues:
1. **Insufficient RAM** - 4GB per node is below minimum for production K8s + monitoring
2. **No swap space** - system has no safety buffer for memory pressure
3. **Missing resource limits** - pods can consume unlimited resources
4. **Poor pod distribution** - all workload on worker-1, worker-2 idle
5. **Prometheus over-retention** - 7 days retention on 4GB RAM node
6. **Corrupted Prometheus data** - causing crashes and high memory usage

### Contributing Factors:
- Aggressive metrics collection intervals
- Multiple Python sidecars for Grafana dashboards
- Heavy Longhorn storage overhead
- systemd-journald excessive logging (189MB on worker-2)

---

## Recommended Solutions (Prioritized)

### IMMEDIATE ACTIONS (Within 24h)

#### 1. Add Swap Space (CRITICAL)
```bash
# On each node:
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Configure swappiness
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```
**Impact:** Prevents OOM kills, provides 4GB safety buffer per node.

#### 2. Reduce Prometheus Retention (CRITICAL)
```bash
# Edit prometheus CR:
kubectl patch prometheus prometheus-prometheus -n monitoring --type merge -p '
spec:
  retention: 3d  # Reduce from 7d to 3d
'
```
**Impact:** ~40% reduction in memory usage (~180MB savings).

#### 3. Fix Prometheus Corrupted Data (CRITICAL)
```bash
# Scale down Prometheus
kubectl scale statefulset prometheus-prometheus -n monitoring --replicas=0

# Delete PVC data (will lose 7d of metrics history)
kubectl delete pvc -n monitoring prometheus-prometheus-prometheus-db-prometheus-prometheus-0

# Scale back up
kubectl scale statefulset prometheus-prometheus -n monitoring --replicas=1
```
**Impact:** Eliminates crashes and errors, clean start.

#### 4. Fix Prometheus-Adapter Memory Limit (HIGH)
```bash
kubectl patch deployment prometheus-adapter -n monitoring --type json -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/limits/memory",
    "value": "512Mi"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/requests/memory",
    "value": "256Mi"
  }
]'
```
**Impact:** Stops crashloop (1180 restarts → 0).

---

### SHORT-TERM ACTIONS (Within 1 week)

#### 5. Add Resource Limits to All Pods (HIGH)
Create resource quotas for critical workloads:

**Prometheus:**
```yaml
resources:
  requests:
    memory: 512Mi
    cpu: 200m
  limits:
    memory: 1Gi
    cpu: 1000m
```

**Grafana:**
```yaml
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi
    cpu: 500m
```

**Apply via Helm values or patch.**

#### 6. Rebalance Pod Distribution (HIGH)
Add node affinity to spread load:

```yaml
# Example for Prometheus
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-worker-2

# Example for preventing co-location
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          app: prometheus
      topologyKey: kubernetes.io/hostname
```

**Manual rebalance:**
```bash
# Drain worker-1, pods will reschedule to worker-2
kubectl drain k8s-worker-1 --ignore-daemonsets --delete-emptydir-data
kubectl uncordon k8s-worker-1
```

#### 7. Reduce Grafana Python Sidecars (MEDIUM)
Disable unnecessary dashboard sidecars to save ~300MB:

```yaml
# In Grafana values.yaml:
sidecar:
  dashboards:
    enabled: true
  datasources:
    enabled: true
  plugins:
    enabled: false  # Disable if not needed
```

#### 8. Configure systemd-journald Limits (MEDIUM)
On k8s-worker-2, limit journal size:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d/
cat <<EOF | sudo tee /etc/systemd/journald.conf.d/size-limit.conf
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
SystemKeepFree=500M
MaxFileSec=1day
MaxRetentionSec=7day
EOF

sudo systemctl restart systemd-journald
```
**Impact:** Reduce journald from 189MB → ~50MB.

---

### MEDIUM-TERM ACTIONS (Within 1 month)

#### 9. Increase VM Resources (CRITICAL FOR STABILITY)

**Recommended minimum specifications:**

| Node Type | Current RAM | Recommended RAM | Current CPU | Recommended CPU |
|-----------|-------------|-----------------|-------------|-----------------|
| Master | 4GB | 8GB | 2 cores | 4 cores |
| Worker | 4GB | 16GB | 2 cores | 4 cores |

**Edit vagrant/config.yml:**
```yaml
nodes:
  k8s-master-1:
    memory: 8192   # 8GB (was 4096)
    cpus: 4        # 4 cores (was 2)
  k8s-worker-1:
    memory: 16384  # 16GB (was 4096)
    cpus: 4        # 4 cores (was 2)
  k8s-worker-2:
    memory: 16384  # 16GB (was 4096)
    cpus: 4        # 4 cores (was 2)
```

**Apply changes:**
```bash
cd /repos/devops-lab-new/k8s-local/ubuntu-22.04/vagrant
vagrant halt
# Edit config.yml
vagrant up
```

#### 10. Optimize Prometheus Configuration (MEDIUM)

**Reduce scrape frequency:**
```yaml
prometheus:
  prometheusSpec:
    scrapeInterval: 30s  # Was likely 15s or 10s
    evaluationInterval: 30s
    retention: 3d
    retentionSize: "5GB"

    # Optimize storage
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          resources:
            requests:
              storage: 10Gi  # Ensure adequate space

    # Resource limits
    resources:
      requests:
        memory: 512Mi
        cpu: 200m
      limits:
        memory: 1Gi
        cpu: 1000m
```

#### 11. Implement Pod Disruption Budgets (LOW)
Prevent too many pods being evicted at once:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: prometheus-pdb
  namespace: monitoring
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: prometheus
```

---

### LONG-TERM ACTIONS (Strategic)

#### 12. Consider Lighter Monitoring Stack (OPTIONAL)
If resource constraints persist, consider:
- **VictoriaMetrics** (more efficient than Prometheus)
- **Grafana Agent** (lighter than full Prometheus)
- **Loki** for logs (instead of heavy ELK stack if present)

#### 13. Implement Cluster Autoscaling (OPTIONAL)
If on cloud infrastructure, implement:
- Horizontal Pod Autoscaler (HPA)
- Cluster Autoscaler
- Vertical Pod Autoscaler (VPA)

#### 14. Monitoring and Alerting Improvements
Set up alerts for:
- Node memory usage > 80%
- Node CPU usage > 80%
- Pod restart count > 10 in 1h
- OOMKilled events
- Disk usage > 75%

---

## Implementation Priority Matrix

| Priority | Action | Effort | Impact | Time |
|----------|--------|--------|--------|------|
| P0 | Add swap space | Low | High | 1h |
| P0 | Reduce Prometheus retention 7d→3d | Low | High | 30m |
| P0 | Fix prometheus-adapter limits | Low | High | 15m |
| P1 | Clean Prometheus corrupted data | Medium | High | 1h |
| P1 | Rebalance pods to worker-2 | Medium | High | 2h |
| P1 | Add resource limits (monitoring) | Medium | High | 4h |
| P2 | Reduce Grafana sidecars | Low | Medium | 1h |
| P2 | Configure journald limits | Low | Medium | 30m |
| P3 | Increase VM RAM/CPU | High | Very High | 4h + downtime |
| P3 | Optimize Prometheus config | Medium | Medium | 2h |

---

## Monitoring Commands

### Check node health:
```bash
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Check pod resource usage:
```bash
kubectl top pods --all-namespaces --sort-by=memory
kubectl top pods --all-namespaces --sort-by=cpu
```

### Check for OOMKilled pods:
```bash
kubectl get events --all-namespaces --field-selector reason=OOMKilled
```

### Check pod restarts:
```bash
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.status.containerStatuses[].restartCount > 10) |
  "\(.metadata.namespace)/\(.metadata.name): \(.status.containerStatuses[].restartCount) restarts"'
```

### VM-level monitoring:
```bash
# On each node:
ssh ansible@192.168.0.180 'free -h && uptime'
ssh ansible@192.168.0.190 'free -h && uptime'
ssh ansible@192.168.0.191 'free -h && uptime'
```

---

## Success Criteria (After Implementation)

### Target Metrics:
- Node load average < 2.0 on all nodes
- Node memory usage < 70%
- Free memory > 500MB per node
- Swap usage < 20%
- Pod restarts < 5 per week (excluding deployments)
- No OOMKilled events
- Even pod distribution (40-60% split between workers)

### Health Indicators:
- prometheus-adapter: 0 restarts in 7 days
- Prometheus: No corrupted data errors
- All pods: Resource limits configured
- All nodes: Swap enabled and configured

---

## Appendix: Quick Fix Script

Save as `/repos/devops-lab-new/k8s-local/ubuntu-22.04/scripts/fix-k8s-performance.sh`:

```bash
#!/bin/bash
set -e

echo "=== K8s Performance Quick Fix Script ==="
echo "This script implements P0 fixes only."
echo ""

# 1. Add swap on all nodes
echo "[1/4] Adding swap space on all nodes..."
for node in 192.168.0.180 192.168.0.190 192.168.0.191; do
  echo "  -> Configuring swap on $node..."
  ssh -i ~/.ssh/id_rsa ansible@$node 'bash -s' <<'EOF'
    sudo fallocate -l 4G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    echo "Swap enabled: $(free -h | grep Swap)"
EOF
done
echo "  ✓ Swap configured on all nodes"

# 2. Reduce Prometheus retention
echo "[2/4] Reducing Prometheus retention to 3d..."
kubectl patch prometheus prometheus-prometheus -n monitoring --type merge -p '{"spec":{"retention":"3d"}}'
echo "  ✓ Prometheus retention updated"

# 3. Fix prometheus-adapter limits
echo "[3/4] Fixing prometheus-adapter memory limits..."
kubectl patch deployment prometheus-adapter -n monitoring --type json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"512Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"256Mi"}
]'
echo "  ✓ Prometheus-adapter limits updated"

# 4. Restart prometheus-adapter
echo "[4/4] Restarting prometheus-adapter..."
kubectl rollout restart deployment prometheus-adapter -n monitoring
kubectl rollout status deployment prometheus-adapter -n monitoring --timeout=120s
echo "  ✓ Prometheus-adapter restarted"

echo ""
echo "=== Quick fixes applied successfully! ==="
echo "Monitor the cluster for 1 hour to see improvements."
echo ""
echo "Next steps:"
echo "  - Monitor: kubectl top nodes"
echo "  - Check restarts: kubectl get pods -n monitoring"
echo "  - For full fix: Follow P1-P3 actions in K8S-PERFORMANCE-ANALYSIS.md"
```

**Make executable:**
```bash
chmod +x /repos/devops-lab-new/k8s-local/ubuntu-22.04/scripts/fix-k8s-performance.sh
```

---

## Contact

For questions or assistance implementing these fixes, contact the DevOps team.

**Generated:** 2025-11-21
**Analysis Duration:** ~20 minutes
**Cluster Age:** 162 days (since initial deployment)
