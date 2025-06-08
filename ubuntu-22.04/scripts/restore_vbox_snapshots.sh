#!/bin/bash

SNAP_NAME="$1"

if [ -z "$SNAP_NAME" ]; then
  echo "Usage: $0 <snapshot_name>"
  exit 1
fi

# List of VM names to restore
VM_LIST=(
  # "k8s-lb"
  # "k8s-master-1"
  # "k8s-master-2"
 "k8s-worker-1"
 "k8s-worker-2"
)

for VM in "${VM_LIST[@]}"; do
  echo "Restoring snapshot '$SNAP_NAME' for VM: $VM"
  VBoxManage controlvm "$VM" poweroff 2>/dev/null
  VBoxManage snapshot "$VM" restore "$SNAP_NAME" || echo "Restore failed for $VM"
  VBoxManage startvm "$VM" --type headless
done
