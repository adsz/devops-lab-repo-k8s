#!/bin/bash
set -e

echo "=== K8s Performance Quick Fix Script ==="
echo "This script implements P0 (critical priority) fixes only."
echo ""

# 1. Add swap on all nodes
echo "[1/4] Adding swap space on all nodes..."
for node in 192.168.0.180 192.168.0.190 192.168.0.191; do
  echo "  -> Configuring swap on $node..."
  ssh -i ~/.ssh/id_rsa ansible@$node 'bash -s' <<'EOF'
    # Check if swap already exists
    if [ $(swapon --show | wc -l) -eq 0 ]; then
      sudo fallocate -l 4G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
      sudo chmod 600 /swapfile
      sudo mkswap /swapfile
      sudo swapon /swapfile

      # Add to fstab if not already present
      if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
      fi

      # Configure swappiness
      if ! grep -q 'vm.swappiness' /etc/sysctl.conf; then
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
      fi
      sudo sysctl -p
      echo "Swap enabled: $(free -h | grep Swap)"
    else
      echo "Swap already configured: $(free -h | grep Swap)"
    fi
EOF
done
echo "  ✓ Swap configured on all nodes"

# 2. Reduce Prometheus retention
echo "[2/4] Reducing Prometheus retention to 3d..."
kubectl patch prometheus prometheus-prometheus -n monitoring --type merge -p '{"spec":{"retention":"3d"}}'
echo "  ✓ Prometheus retention updated (will take effect on next restart)"

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
echo "  Waiting for rollout to complete..."
kubectl rollout status deployment prometheus-adapter -n monitoring --timeout=120s
echo "  ✓ Prometheus-adapter restarted"

echo ""
echo "=== Quick fixes applied successfully! ==="
echo ""
echo "Current cluster status:"
kubectl top nodes 2>/dev/null || echo "  (metrics-server may need a moment to stabilize)"
echo ""
echo "Monitor the cluster for 1 hour to see improvements:"
echo "  - Check load: watch 'kubectl top nodes'"
echo "  - Check restarts: kubectl get pods -n monitoring"
echo "  - Check swap: ssh ansible@192.168.0.180 'free -h'"
echo ""
echo "Next steps (implement P1-P3 actions):"
echo "  - Rebalance pods to worker-2 (see K8S-PERFORMANCE-ANALYSIS.md)"
echo "  - Add resource limits to all pods"
echo "  - Clean Prometheus corrupted data (if errors persist)"
echo "  - Consider increasing VM RAM to 8-16GB per node"
echo ""
echo "Full analysis: /repos/devops-lab-new/k8s-local/ubuntu-22.04/K8S-PERFORMANCE-ANALYSIS.md"
