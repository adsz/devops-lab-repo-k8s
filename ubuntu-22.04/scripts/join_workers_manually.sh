#!/bin/bash

echo "=== Simple Worker Join Script ==="

# Get join command
echo "1. Getting join command from master..."
JOIN_CMD=$(ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no ansible@192.168.0.180 "sudo kubeadm token create --print-join-command")

echo "Join command: $JOIN_CMD"

# Join worker 1
echo "2. Joining k8s-worker-1..."
ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no ansible@192.168.0.190 "sudo $JOIN_CMD"

# Join worker 2  
echo "3. Joining k8s-worker-2..."
ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no ansible@192.168.0.191 "sudo $JOIN_CMD"

# Label workers with node-role.kubernetes.io/worker
echo "4. Labeling workers..."
ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no ansible@192.168.0.180 "
  kubectl label node k8s-worker-1 node-role.kubernetes.io/worker= --overwrite && \
  kubectl label node k8s-worker-2 node-role.kubernetes.io/worker= --overwrite
"
# Check status
echo "5. Checking cluster status..."
ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no ansible@192.168.0.180 "kubectl get nodes -o wide"

echo "=== Done ==="