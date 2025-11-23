#!/bin/bash
#
# Pre-Upgrade Health Check Script
# Validates cluster readiness before Kubernetes version upgrade
#
# Usage: ./pre-upgrade-check.sh [target-version]
# Example: ./pre-upgrade-check.sh 1.30

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

TARGET_VERSION="${1:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Kubernetes Pre-Upgrade Health Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Date: $(date)"
echo "Current K8s Version: $(kubectl version --short 2>/dev/null | grep Server || kubectl version -o json | jq -r '.serverVersion.gitVersion')"
if [ -n "$TARGET_VERSION" ]; then
    echo "Target K8s Version: v$TARGET_VERSION"
fi
echo ""

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# 1. Check nodes status
echo -e "\n${BLUE}[1/15]${NC} Checking Node Status..."
if kubectl get nodes | grep -q "NotReady"; then
    check_fail "Some nodes are NotReady"
    kubectl get nodes
else
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    check_pass "All $NODE_COUNT nodes are Ready"
fi

# 2. Check pods status
echo -e "\n${BLUE}[2/15]${NC} Checking Pod Status..."
PROBLEM_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
if [ "$PROBLEM_PODS" -gt 0 ]; then
    check_warn "$PROBLEM_PODS pods are not Running/Succeeded"
    kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
else
    TOTAL_PODS=$(kubectl get pods -A --no-headers | wc -l)
    check_pass "All $TOTAL_PODS pods are Running or Succeeded"
fi

# 3. Check PersistentVolumeClaims
echo -e "\n${BLUE}[3/15]${NC} Checking PersistentVolumeClaims..."
PENDING_PVCS=$(kubectl get pvc -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
if [ "$PENDING_PVCS" -gt 0 ]; then
    check_warn "$PENDING_PVCS PVCs are Pending"
    kubectl get pvc -A --field-selector=status.phase=Pending
else
    check_pass "No pending PVCs"
fi

# 4. Check etcd health
echo -e "\n${BLUE}[4/15]${NC} Checking etcd Health..."
if kubectl get pods -n kube-system -l component=etcd --no-headers | grep -q "Running"; then
    ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n kube-system "$ETCD_POD" -- etcdctl \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        endpoint health &>/dev/null; then
        check_pass "etcd is healthy"
    else
        check_fail "etcd health check failed"
    fi
else
    check_fail "etcd pod not running"
fi

# 5. Check API server
echo -e "\n${BLUE}[5/15]${NC} Checking API Server..."
if kubectl get --raw /healthz &>/dev/null; then
    check_pass "API server is healthy"
else
    check_fail "API server health check failed"
fi

# 6. Check disk space on all nodes
echo -e "\n${BLUE}[6/15]${NC} Checking Disk Space..."
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    NODE_IP=$(kubectl get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    if [ "$node" = "k8s-master-1" ]; then
        DISK_AVAIL=$(ssh ansible@"$NODE_IP" "df -h / | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "unknown")
    else
        DISK_AVAIL=$(ssh ansible@"$NODE_IP" "df -h / | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "unknown")
    fi

    if [ "$DISK_AVAIL" = "unknown" ]; then
        check_warn "$node: Unable to check disk space"
    else
        DISK_NUM=$(echo "$DISK_AVAIL" | sed 's/G.*//')
        if [ "$DISK_NUM" -lt 10 ]; then
            check_fail "$node: Only $DISK_AVAIL available (need >10GB)"
        elif [ "$DISK_NUM" -lt 20 ]; then
            check_warn "$node: $DISK_AVAIL available (recommended >20GB)"
        else
            check_pass "$node: $DISK_AVAIL available"
        fi
    fi
done

# 7. Check DNS resolution
echo -e "\n${BLUE}[7/15]${NC} Checking DNS Resolution..."
if kubectl run test-dns --image=busybox:1.28 --rm -i --restart=Never --command -- nslookup kubernetes.default &>/dev/null; then
    check_pass "DNS resolution working"
else
    check_fail "DNS resolution test failed"
fi

# 8. Check certificates expiration
echo -e "\n${BLUE}[8/15]${NC} Checking Certificate Expiration..."
MASTER_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
CERT_EXPIRY=$(ssh ansible@"$MASTER_IP" "sudo kubeadm certs check-expiration 2>/dev/null | grep apiserver | head -1 | awk '{print \$3, \$4, \$5}'" 2>/dev/null || echo "unknown")

if [ "$CERT_EXPIRY" = "unknown" ]; then
    check_warn "Unable to check certificate expiration"
else
    check_pass "Certificates valid until: $CERT_EXPIRY"
fi

# 9. Check metrics server
echo -e "\n${BLUE}[9/15]${NC} Checking Metrics Server..."
if kubectl top nodes &>/dev/null; then
    check_pass "Metrics server is working"
else
    check_warn "Metrics server not available (kubectl top won't work)"
fi

# 10. Check Velero backups
echo -e "\n${BLUE}[10/15]${NC} Checking Velero Backups..."
if kubectl get deployment velero -n velero &>/dev/null; then
    LATEST_BACKUP=$(kubectl get backup -n velero --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "none")
    if [ "$LATEST_BACKUP" = "none" ]; then
        check_warn "No Velero backups found"
    else
        BACKUP_STATUS=$(kubectl get backup -n velero "$LATEST_BACKUP" -o jsonpath='{.status.phase}')
        BACKUP_TIME=$(kubectl get backup -n velero "$LATEST_BACKUP" -o jsonpath='{.status.startTimestamp}')
        if [ "$BACKUP_STATUS" = "Completed" ]; then
            check_pass "Latest Velero backup: $LATEST_BACKUP ($BACKUP_TIME)"
        else
            check_warn "Latest Velero backup status: $BACKUP_STATUS"
        fi
    fi
else
    check_warn "Velero not installed"
fi

# 11. Check addon compatibility
echo -e "\n${BLUE}[11/15]${NC} Checking Critical Addons..."

# Check CNI (Calico)
if kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers | grep -q "Running"; then
    CALICO_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers | grep "Running" | wc -l)
    check_pass "Calico CNI running ($CALICO_PODS pods)"
else
    check_fail "Calico CNI not running properly"
fi

# Check CoreDNS
if kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -q "Running"; then
    check_pass "CoreDNS running"
else
    check_fail "CoreDNS not running"
fi

# 12. Check kube-proxy
echo -e "\n${BLUE}[12/15]${NC} Checking kube-proxy..."
KUBE_PROXY_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-proxy --no-headers | grep "Running" | wc -l)
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$KUBE_PROXY_PODS" -eq "$NODE_COUNT" ]; then
    check_pass "kube-proxy running on all $NODE_COUNT nodes"
else
    check_fail "kube-proxy pods: $KUBE_PROXY_PODS, expected: $NODE_COUNT"
fi

# 13. Check for deprecated APIs
echo -e "\n${BLUE}[13/15]${NC} Checking for Deprecated APIs..."
if [ -n "$TARGET_VERSION" ]; then
    check_warn "Manual review required: Check API deprecations for v$TARGET_VERSION"
    echo "    Reference: https://kubernetes.io/docs/reference/using-api/deprecation-guide/"
else
    check_warn "Target version not specified, skipping API deprecation check"
fi

# 14. Check cluster load
echo -e "\n${BLUE}[14/15]${NC} Checking Cluster Resource Usage..."
if kubectl top nodes &>/dev/null; then
    echo "Current resource usage:"
    kubectl top nodes
    check_pass "Resource metrics available"
else
    check_warn "Unable to get resource metrics"
fi

# 15. Check recent events
echo -e "\n${BLUE}[15/15]${NC} Checking Recent Events..."
ERROR_EVENTS=$(kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' -o json | jq '.items | length' 2>/dev/null || echo "0")
if [ "$ERROR_EVENTS" -gt 10 ]; then
    check_warn "$ERROR_EVENTS warning events in the last hour"
    echo "Recent warnings:"
    kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -5
else
    check_pass "Only $ERROR_EVENTS warning events (acceptable)"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Pre-Upgrade Check Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}❌ CLUSTER NOT READY FOR UPGRADE${NC}"
    echo "Please fix the failed checks before proceeding with upgrade."
    exit 1
elif [ "$WARNINGS" -gt 5 ]; then
    echo -e "${YELLOW}⚠️  PROCEED WITH CAUTION${NC}"
    echo "Multiple warnings detected. Review before upgrade."
    exit 2
else
    echo -e "${GREEN}✅ CLUSTER READY FOR UPGRADE${NC}"
    echo "All critical checks passed. You may proceed with the upgrade."
    exit 0
fi
