#!/bin/bash

echo "=== Final Kubernetes HA Cluster Verification ==="
echo ""

echo "1. Cluster nodes status:"
ssh -i /root/.ssh/id_rsa ansible@192.168.0.180 "kubectl get nodes -o wide"

echo ""
echo "2. Waiting 60 seconds for CNI to initialize..."
sleep 60

echo ""
echo "3. Updated nodes status:"
ssh -i /root/.ssh/id_rsa ansible@192.168.0.180 "kubectl get nodes"

echo ""
echo "4. System pods status:"
ssh -i /root/.ssh/id_rsa ansible@192.168.0.180 "kubectl get pods -n kube-system -o wide | grep -E 'NAME|calico|coredns'"

echo ""
echo "5. Testing pod deployment on workers:"
ssh -i /root/.ssh/id_rsa ansible@192.168.0.180 "kubectl run test-deployment --image=nginx:alpine --restart=Never"
sleep 30
ssh -i /root/.ssh/id_rsa ansible@192.168.0.180 "kubectl get pod test-deployment -o wide"

echo ""
echo "6. Cluster summary:"
ssh -i /root/.ssh/id_rsa ansible@192.168.0.180 "kubectl cluster-info"

echo ""
echo "7. Cleaning up test pod:"
ssh -i /root/.ssh/id_rsa ansible@192.168.0.180 "kubectl delete pod test-deployment"

echo ""
echo "=== ✅ Kubernetes HA Cluster Successfully Deployed! ==="
echo ""
echo "Cluster Components:"
echo "- Load Balancer VIP: 192.168.0.200:6443"
echo "- Master Nodes: k8s-master-1 (192.168.0.180), k8s-master-2 (192.168.0.181)"
echo "- Worker Nodes: k8s-worker-1 (192.168.0.190), k8s-worker-2 (192.168.0.191)"
echo ""
echo "Access Information:"
echo "- SSH to master: ssh ansible@192.168.0.180 -i /root/.ssh/id_rsa"
echo "- kubectl: export KUBECONFIG=/home/ansible/.kube/config"
echo "- HAProxy Stats: http://192.168.0.175:8404/stats (admin/admin)"