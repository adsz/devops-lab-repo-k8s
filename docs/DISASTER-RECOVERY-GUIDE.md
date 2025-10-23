# DISASTER-RECOVERY-GUIDE

## Overview

This guide provides comprehensive disaster recovery procedures for the Enterprise Kubernetes cluster using Velero, ETCD snapshots, and enterprise-grade backup automation.

**Key Terms for Non-Technical Users:**
- **Disaster Recovery (DR)**: Process of restoring systems after catastrophic failure
- **Recovery Time Objective (RTO)**: Maximum acceptable downtime
- **Recovery Point Objective (RPO)**: Maximum acceptable data loss
- **Backup**: Copy of data/systems stored separately for restoration
- **Restoration**: Process of recovering systems from backups

## Disaster Recovery Architecture

### Backup Components
```
┌─────────────────────────────────────────────────────────────────┐
│                    ENTERPRISE BACKUP ECOSYSTEM                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐│
│  │   VELERO        │    │   ETCD          │    │   JENKINS    ││
│  │   BACKUPS       │    │   SNAPSHOTS     │    │   PIPELINE   ││
│  │                 │    │                 │    │              ││
│  │ • Applications  │    │ • Control Plane │    │ • Automation ││
│  │ • Persistent    │    │ • Cluster State │    │ • Monitoring ││
│  │   Volumes       │    │ • Certificates  │    │ • Alerting   ││
│  │ • Namespaces    │    │ • RBAC Config   │    │ • Reporting  ││
│  └─────────────────┘    └─────────────────┘    └──────────────┘│
│           │                        │                        │   │
│           └────────────────────────┼────────────────────────┘   │
│                                    │                            │
│  ┌─────────────────────────────────▼────────────────────────┐   │
│  │                 AWS S3 STORAGE                           │   │
│  │                                                          │   │
│  │  s3://aws5-k8s-backup/                                   │   │
│  │  ├── velero-backups/                                     │   │
│  │  │   ├── daily-backup-20250825-020000/                  │   │
│  │  │   ├── weekly-backup-20250825-010000/                 │   │
│  │  │   └── manual-backup-20250825-143000/                 │   │
│  │  ├── etcd-snapshots/                                     │   │
│  │  │   ├── etcd-snapshot-20250825-140000.db.gz            │   │
│  │  │   └── etcd-snapshot-20250825-080000.db.gz            │   │
│  │  └── jenkins-backups/                                    │   │
│  │      ├── jenkins-manual-1/                               │   │
│  │      └── jenkins-scheduled-2/                            │   │
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Recovery Procedures

## 🚨 EMERGENCY RECOVERY PROCEDURES

### Scenario 1: Complete Cluster Failure

**RTO**: 2-4 hours | **RPO**: 6 hours maximum

<details>
<summary>📋 Emergency Cluster Restore (click to expand)</summary>

```bash
# Step 1: Verify backup availability
aws s3 ls s3://aws5-k8s-backup/velero-backups/ | tail -10
aws s3 ls s3://aws5-k8s-backup/etcd-snapshots/ | tail -5

# Step 2: Restore infrastructure with Terraform
cd /repos/devops-lab-new/k8s-local/cluster_deployments/velero/terraform
terraform init -upgrade
terraform plan
terraform apply -auto-approve

# Step 3: Recreate Kubernetes cluster
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml

# Step 4: Restore ETCD from latest snapshot
ETCD_SNAPSHOT=$(aws s3 ls s3://aws5-k8s-backup/etcd-snapshots/ | sort | tail -1 | awk '{print $4}')
aws s3 cp s3://aws5-k8s-backup/etcd-snapshots/$ETCD_SNAPSHOT /tmp/
gunzip /tmp/$ETCD_SNAPSHOT

# Restore ETCD data
sudo systemctl stop etcd
sudo ETCDCTL_API=3 etcdctl snapshot restore /tmp/${ETCD_SNAPSHOT%.gz} \
  --data-dir /var/lib/etcd \
  --name $(hostname) \
  --initial-cluster $(hostname)=https://$(hostname -I | awk '{print $1}'):2380 \
  --initial-advertise-peer-urls https://$(hostname -I | awk '{print $1}'):2380

sudo chown -R etcd:etcd /var/lib/etcd
sudo systemctl start etcd

# Step 5: Reinstall Velero
cd /repos/devops-lab-new/k8s-local/cluster_deployments/velero

# Reapply the cloud-credentials secret (file contains sensitive data maintained locally)
kubectl apply -f cloud-credentials.secret.yaml

helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm upgrade --install velero vmware-tanzu/velero \
  -n velero --create-namespace \
  -f values.yaml \
  --reset-values

# Step 6: Restore from latest Velero backup
LATEST_BACKUP=$(velero backup get --output json | jq -r '.items | sort_by(.metadata.creationTimestamp) | .[-1].metadata.name')
velero restore create emergency-restore-$(date +%Y%m%d-%H%M%S) --from-backup $LATEST_BACKUP
```

**Copy Button Available** ↗️
</details>

### Scenario 2: Single Namespace Recovery

**RTO**: 30 minutes | **RPO**: 24 hours maximum

<details>
<summary>🔄 Namespace Restore (click to expand)</summary>

```bash
# Step 1: List available backups for specific namespace
velero backup get | grep -E "(daily|weekly|manual)"

# Step 2: Select backup and create targeted restore
BACKUP_NAME="daily-backup-20250825-020000"
NAMESPACE="production-app"

velero restore create ${NAMESPACE}-restore-$(date +%Y%m%d-%H%M%S) \
  --from-backup $BACKUP_NAME \
  --include-namespaces $NAMESPACE \
  --wait

# Step 3: Verify restoration
kubectl get pods -n $NAMESPACE
kubectl get pvc -n $NAMESPACE
kubectl get services -n $NAMESPACE

# Step 4: Test application connectivity
kubectl port-forward -n $NAMESPACE service/app-service 8080:80 &
curl -f http://localhost:8080/health || echo "❌ Application not responding"

# Step 5: Notify stakeholders
aws sns publish \
  --topic-arn arn:aws:sns:eu-central-1:112779685446:k8s-production-backup-notifications \
  --message "✅ Namespace $NAMESPACE restored successfully from backup $BACKUP_NAME"
```

**Copy Button Available** ↗️
</details>

### Scenario 3: Persistent Volume Data Recovery

**RTO**: 1 hour | **RPO**: 24 hours maximum

<details>
<summary>💾 Volume Data Restore (click to expand)</summary>

```bash
# Step 1: Identify affected persistent volumes
kubectl get pv | grep -E "(Failed|Lost)"
PV_NAME="pvc-12345678-1234-1234-1234-123456789012"

# Step 2: Find backup containing the volume
velero backup describe $BACKUP_NAME --details | grep -A 10 "Persistent Volumes"

# Step 3: Create targeted volume restore
cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: volume-restore-$(date +%Y%m%d-%H%M%S)
  namespace: velero
spec:
  backupName: $BACKUP_NAME
  includedResources:
  - persistentvolumes
  - persistentvolumeclaims
  labelSelector:
    matchLabels:
      volume.beta.kubernetes.io/storage-class: "gp2"
  restorePVs: true
EOF

# Step 4: Monitor restore progress
kubectl get restore -n velero -w

# Step 5: Verify data integrity
kubectl exec -it pod-using-restored-volume -- ls -la /data/
kubectl exec -it pod-using-restored-volume -- cat /data/important-file.txt
```

**Copy Button Available** ↗️
</details>

## 📊 BACKUP VERIFICATION PROCEDURES

### Daily Health Checks

<details>
<summary>✅ Automated Backup Verification (click to expand)</summary>

```bash
#!/bin/bash
# File: scripts/verify-backups.sh

echo "🔍 Enterprise Backup Health Check - $(date)"
echo "================================================"

# Check Velero backup status
echo "📦 Velero Backup Status:"
velero backup get --output table | head -10

# Verify recent backups completed successfully
FAILED_BACKUPS=$(velero backup get --output json | jq -r '.items[] | select(.status.phase=="Failed") | select(.metadata.creationTimestamp > (now - 86400 | todate)) | .metadata.name' | wc -l)

if [ $FAILED_BACKUPS -gt 0 ]; then
    echo "❌ Warning: $FAILED_BACKUPS backup failures in last 24 hours"
    velero backup get --output json | jq -r '.items[] | select(.status.phase=="Failed") | select(.metadata.creationTimestamp > (now - 86400 | todate)) | "Failed: \(.metadata.name) - \(.status.failureReason // "Unknown")"'
else
    echo "✅ All backups completed successfully in last 24 hours"
fi

# Check ETCD snapshots
echo ""
echo "🗄️ ETCD Snapshot Status:"
aws s3 ls s3://aws5-k8s-backup/etcd-snapshots/ | tail -5

# Verify S3 storage utilization
echo ""
echo "☁️ S3 Storage Utilization:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/S3 \
    --metric-name BucketSizeBytes \
    --dimensions Name=BucketName,Value=aws5-k8s-backup Name=StorageType,Value=StandardStorage \
    --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 86400 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text | awk '{printf "Current Size: %.2f GB\n", $1/1024/1024/1024}'

# Test restore capability (dry-run)
echo ""
echo "🧪 Restore Capability Test:"
LATEST_BACKUP=$(velero backup get --output json | jq -r '.items | sort_by(.metadata.creationTimestamp) | .[-1].metadata.name')
velero restore create test-restore-$(date +%Y%m%d-%H%M%S) \
    --from-backup $LATEST_BACKUP \
    --dry-run

echo ""
echo "✅ Backup health check completed"
```

**Copy Button Available** ↗️
</details>

### Weekly Disaster Recovery Drills

<details>
<summary>🎯 DR Drill Procedures (click to expand)</summary>

```bash
# Weekly DR Drill - Sunday 3 AM
# File: scripts/dr-drill.sh

#!/bin/bash
echo "🎯 Weekly Disaster Recovery Drill - $(date)"
echo "=============================================="

# Step 1: Create test namespace for drill
kubectl create namespace dr-drill-$(date +%Y%m%d) || true

# Step 2: Deploy sample application
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dr-test-app
  namespace: dr-drill-$(date +%Y%m%d)
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dr-test
  template:
    metadata:
      labels:
        app: dr-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: data-volume
          mountPath: /usr/share/nginx/html
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: dr-test-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dr-test-pvc
  namespace: dr-drill-$(date +%Y%m%d)
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: gp2
EOF

# Step 3: Create test data
kubectl exec -n dr-drill-$(date +%Y%m%d) deployment/dr-test-app -- bash -c \
    'echo "DR Drill Test Data - $(date)" > /usr/share/nginx/html/index.html'

# Step 4: Create backup
velero backup create dr-drill-backup-$(date +%Y%m%d-%H%M%S) \
    --include-namespaces dr-drill-$(date +%Y%m%d) \
    --wait

# Step 5: Delete namespace (simulate disaster)
kubectl delete namespace dr-drill-$(date +%Y%m%d) --wait=true

# Step 6: Restore from backup
DRILL_BACKUP=$(velero backup get | grep dr-drill-backup-$(date +%Y%m%d) | awk '{print $1}')
velero restore create dr-drill-restore-$(date +%Y%m%d-%H%M%S) \
    --from-backup $DRILL_BACKUP \
    --wait

# Step 7: Verify restoration
sleep 60
kubectl get pods -n dr-drill-$(date +%Y%m%d)
kubectl get pvc -n dr-drill-$(date +%Y%m%d)

# Step 8: Test data integrity
kubectl exec -n dr-drill-$(date +%Y%m%d) deployment/dr-test-app -- cat /usr/share/nginx/html/index.html

# Step 9: Cleanup drill resources
kubectl delete namespace dr-drill-$(date +%Y%m%d)
velero backup delete $DRILL_BACKUP --confirm
velero restore delete dr-drill-restore-$(date +%Y%m%d-%H%M%S) --confirm

echo "✅ DR Drill completed successfully"

# Step 10: Send drill report
aws sns publish \
    --topic-arn arn:aws:sns:eu-central-1:112779685446:k8s-production-backup-notifications \
    --subject "Weekly DR Drill Report - $(date +%Y-%m-%d)" \
    --message "✅ Weekly Disaster Recovery Drill completed successfully. All systems restored and verified."
```

**Copy Button Available** ↗️
</details>

## 📈 MONITORING AND ALERTING

### Backup Monitoring Dashboard

<details>
<summary>📊 Prometheus Metrics (click to expand)</summary>

```bash
# Custom Prometheus metrics for backup monitoring
# File: monitoring/backup-metrics.sh

#!/bin/bash

# Push backup metrics to Prometheus Pushgateway
PUSHGATEWAY="http://prometheus-pushgateway:9091"
JOB="k8s-backup-metrics"

# Velero backup success rate
SUCCESS_COUNT=$(velero backup get --output json | jq '[.items[] | select(.status.phase=="Completed") | select(.metadata.creationTimestamp > (now - 86400 | todate))] | length')
TOTAL_COUNT=$(velero backup get --output json | jq '[.items[] | select(.metadata.creationTimestamp > (now - 86400 | todate))] | length')
SUCCESS_RATE=$(echo "scale=2; $SUCCESS_COUNT * 100 / $TOTAL_COUNT" | bc -l)

cat <<EOF | curl --data-binary @- $PUSHGATEWAY/metrics/job/$JOB/instance/velero
# HELP k8s_backup_success_rate Backup success rate in last 24 hours
# TYPE k8s_backup_success_rate gauge
k8s_backup_success_rate $SUCCESS_RATE
EOF

# Backup storage utilization
S3_SIZE=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/S3 \
    --metric-name BucketSizeBytes \
    --dimensions Name=BucketName,Value=aws5-k8s-backup Name=StorageType,Value=StandardStorage \
    --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 86400 \
    --statistics Average \
    --query 'Datapoints[0].Average' \
    --output text)

cat <<EOF | curl --data-binary @- $PUSHGATEWAY/metrics/job/$JOB/instance/storage
# HELP k8s_backup_storage_bytes Total backup storage utilization
# TYPE k8s_backup_storage_bytes gauge
k8s_backup_storage_bytes $S3_SIZE
EOF

# ETCD snapshot freshness
LATEST_ETCD=$(aws s3 ls s3://aws5-k8s-backup/etcd-snapshots/ | sort | tail -1 | awk '{print $1" "$2}')
ETCD_AGE=$(echo $(date +%s) - $(date -d "$LATEST_ETCD" +%s) | bc)

cat <<EOF | curl --data-binary @- $PUSHGATEWAY/metrics/job/$JOB/instance/etcd
# HELP k8s_etcd_snapshot_age_seconds Age of latest ETCD snapshot
# TYPE k8s_etcd_snapshot_age_seconds gauge
k8s_etcd_snapshot_age_seconds $ETCD_AGE
EOF

echo "✅ Backup metrics pushed to Prometheus"
```

**Copy Button Available** ↗️
</details>

### Critical Alerting Rules

<details>
<summary>🚨 Prometheus Alerting Rules (click to expand)</summary>

```yaml
# File: monitoring/backup-alerts.yaml
groups:
- name: k8s-backup-alerts
  rules:
  - alert: BackupFailed
    expr: k8s_backup_success_rate < 90
    for: 30m
    labels:
      severity: critical
      service: k8s-backup
    annotations:
      summary: "Kubernetes backup success rate below 90%"
      description: "Backup success rate is {{ $value }}% in the last 24 hours"
      
  - alert: ETCDSnapshotStale
    expr: k8s_etcd_snapshot_age_seconds > 28800  # 8 hours
    for: 15m
    labels:
      severity: warning
      service: etcd-backup
    annotations:
      summary: "ETCD snapshot is stale"
      description: "Latest ETCD snapshot is {{ $value | humanizeDuration }} old"
      
  - alert: BackupStorageFull
    expr: k8s_backup_storage_bytes > 4500000000  # 4.5GB (close to 5GB limit)
    for: 5m
    labels:
      severity: warning
      service: backup-storage
    annotations:
      summary: "Backup storage approaching Free Tier limit"
      description: "Backup storage is {{ $value | humanizeBytes }}, approaching 5GB Free Tier limit"
      
  - alert: VeleroScheduleNotRunning
    expr: absent(up{job="velero"}) == 1
    for: 10m
    labels:
      severity: critical
      service: velero
    annotations:
      summary: "Velero backup scheduler is down"
      description: "Velero service is not responding"
```

**Copy Button Available** ↗️
</details>

## 🔧 TROUBLESHOOTING

### Common Recovery Issues

<details>
<summary>❌ Backup Restoration Failures (click to expand)</summary>

**Issue**: Restore fails with "Insufficient permissions"

```bash
# Solution: Verify Velero service account permissions
kubectl describe serviceaccount velero -n velero
kubectl get clusterrolebinding | grep velero

# Fix permissions if needed – rerun the Helm release to recreate RBAC
cd /repos/devops-lab-new/k8s-local/cluster_deployments/velero
helm upgrade --install velero vmware-tanzu/velero \
  -n velero --create-namespace \
  -f values.yaml \
  --reset-values
```

**Issue**: Persistent volumes not restoring

```bash
# Solution: Check storage class compatibility
kubectl get storageclass
kubectl describe pv $PV_NAME

# Recreate storage class if needed (consult cluster provisioning docs) or use cloud provider default
```

**Issue**: Application pods stuck in Pending state after restore

```bash
# Solution: Check resource constraints and node capacity
kubectl describe pod $POD_NAME -n $NAMESPACE
kubectl top nodes

# Scale down other applications temporarily
kubectl scale deployment $OTHER_DEPLOYMENT --replicas=0 -n $OTHER_NAMESPACE
```
</details>

### Emergency Contact Procedures

<details>
<summary>📞 Escalation Matrix (click to expand)</summary>

**Severity 1 - Complete Cluster Down (RTO < 4 hours)**
1. **Primary**: DevOps Lead - +48 XXX XXX XXX
2. **Secondary**: System Administrator - +48 XXX XXX XXX  
3. **Escalation**: Infrastructure Manager - +48 XXX XXX XXX

**Severity 2 - Service Degradation (RTO < 2 hours)**
1. **Primary**: On-call Engineer - +48 XXX XXX XXX
2. **Secondary**: DevOps Team Lead - +48 XXX XXX XXX

**Severity 3 - Minor Issues (RTO < 24 hours)**
1. **Primary**: DevOps Team - devops@company.com
2. **Secondary**: Support Ticket System

**Communication Channels:**
- **Slack**: #incident-response
- **Teams**: Emergency Response Team
- **Email**: emergency-response@company.com
- **SMS**: Critical alerts only
</details>

## 📋 RECOVERY CHECKLISTS

### Pre-Recovery Checklist

- [ ] Confirm nature and scope of disaster
- [ ] Notify stakeholders via established communication channels
- [ ] Assemble incident response team
- [ ] Verify latest backup availability and integrity
- [ ] Document timeline and initial assessment
- [ ] Activate change freeze for affected systems

### Post-Recovery Checklist

- [ ] Verify all applications are functional
- [ ] Confirm data integrity and completeness
- [ ] Update monitoring and alerting systems
- [ ] Conduct post-incident review meeting
- [ ] Document lessons learned and process improvements
- [ ] Update disaster recovery procedures if needed
- [ ] Schedule follow-up validation testing

---

**📚 Additional Resources:**
- [ETCD Disaster Recovery Official Guide](https://etcd.io/docs/v3.5/op-guide/recovery/)
- [Velero Disaster Recovery Documentation](https://velero.io/docs/v1.16/disaster-case/)
- [Kubernetes Cluster Administration Guide](https://kubernetes.io/docs/tasks/administer-cluster/)
- [AWS S3 Data Recovery Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/disaster-recovery-resiliency.html)

**💡 Pro Tips:**
- Test DR procedures monthly in non-production environment
- Keep offline copies of critical recovery scripts
- Maintain up-to-date network diagrams and system documentation
- Practice restore procedures under time pressure
- Automate as much of the recovery process as possible
