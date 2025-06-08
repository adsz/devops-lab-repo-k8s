#!/bin/bash

echo "=== Kubernetes State Diagnostic ==="
echo "Time: $(date)"
echo ""

echo "1. Running processes:"
ps aux | grep -E 'kube|etcd' | grep -v grep || echo "No k8s processes"
echo ""

echo "2. Listening ports:"
ss -tlpn | grep -E ':6443|:10259|:10257|:10250|:2379|:2380' || echo "No k8s ports"
echo ""

echo "3. Kubelet service status:"
systemctl status kubelet --no-pager || echo "Kubelet not found"
echo ""

echo "4. Kubernetes directories:"
ls -la /etc/kubernetes/manifests/ 2>/dev/null || echo "No manifests directory"
ls -la /var/lib/etcd/ 2>/dev/null || echo "No etcd directory"
echo ""

echo "5. Container runtime:"
crictl ps -a 2>/dev/null || echo "No containers"
echo ""

echo "6. Systemd drop-ins:"
ls -la /etc/systemd/system/kubelet.service.d/ 2>/dev/null || echo "No kubelet drop-ins"
echo ""

echo "7. Check what created the files:"
stat /etc/kubernetes/manifests/*.yaml 2>/dev/null || echo "No manifest files to stat"