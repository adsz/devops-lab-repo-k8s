#!/bin/bash

SNAP_NAME="$1"

if [ -z "$SNAP_NAME" ]; then
  echo "Usage: $0 <snapshot_name>"
  exit 1
fi

# List of VM names from your Ansible inventory
VM_LIST=(
  "k8s-lb"
  "k8s-master-1"
  "k8s-master-2"
  "k8s-worker-1"
  "k8s-worker-2"
)

for VM in "${VM_LIST[@]}"; do
  echo "Creating snapshot '$SNAP_NAME' for VM: $VM"
  VBoxManage snapshot "$VM" take "$SNAP_NAME" --live || echo "Snapshot failed for $VM"
done
