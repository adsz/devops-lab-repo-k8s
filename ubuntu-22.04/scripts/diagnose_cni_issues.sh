#!/bin/bash

echo "=== Diagnosing CNI Issues ==="
echo ""

echo "1. Checking Calico node logs..."
ansible k8s-master-1 -i inventory.yml -m shell -a "kubectl logs -n kube-system -l k8s-app=calico-node --tail=20" --become-user ansible

echo ""
echo "2. Checking node readiness details..."
ansible k8s-master-1 -i inventory.yml -m shell -a "kubectl describe nodes | grep -A5 -B5 'Ready\\|NotReady'" --become-user ansible

echo ""
echo "3. Checking pod events..."
ansible k8s-master-1 -i inventory.yml -m shell -a "kubectl get events --sort-by=.metadata.creationTimestamp" --become-user ansible

echo ""
echo "4. Checking CNI configuration..."
ansible k8s-masters -i inventory.yml -m shell -a "ls -la /etc/cni/net.d/" --become

echo ""
echo "5. Checking if br_netfilter module is loaded..."
ansible k8s-masters -i inventory.yml -m shell -a "lsmod | grep br_netfilter" --become

echo ""
echo "6. Checking iptables rules..."
ansible k8s-masters -i inventory.yml -m shell -a "iptables -L -n | head -20" --become

echo ""
echo "7. Checking if test pod has any issues..."
ansible k8s-master-1 -i inventory.yml -m shell -a "kubectl describe pod test-pod" --become-user ansible