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

# Check status
echo "4. Checking cluster status..."
ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no ansible@192.168.0.180 "kubectl get nodes -o wide"

echo "=== Done ==="