#!/bin/bash
# File: scripts/list_vbox_snapshots.sh

# List of VM names from your Ansible inventory
VM_LIST=(
  "k8s-lb"
  "k8s-master-1"
  "k8s-master-2"
  "k8s-worker-1"
  "k8s-worker-2"
)

for VM in "${VM_LIST[@]}"; do
  echo "VM: $VM"
  
  # Check if VM exists first
  if ! VBoxManage list vms | grep -q "\"$VM\""; then
    echo "  VM not found"
    echo
    continue
  fi
  
  # Get the config file path
  config_file=$(VBoxManage showvminfo "$VM" --machinereadable | grep "CfgFile=" | cut -d'"' -f2)
  
  if [[ ! -f "$config_file" ]]; then
    echo "  Config file not found"
    echo
    continue
  fi
  
  # Parse snapshots from .vbox XML file
  snapshots_found=false
  while IFS= read -r line; do
    if [[ $line =~ \<Snapshot[[:space:]]+uuid=\"\{([^}]+)\}\"[[:space:]]+name=\"([^\"]+)\"[[:space:]]+timeStamp=\"([^\"]+)\" ]]; then
      uuid="${BASH_REMATCH[1]}"
      name="${BASH_REMATCH[2]}"
      timestamp="${BASH_REMATCH[3]}"
      
      # Convert ISO timestamp to readable format
      readable=$(date -d "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
      if [[ $? -eq 0 ]]; then
        echo "  Snapshot: $name, Created: $readable"
      else
        echo "  Snapshot: $name, Created: $timestamp"
      fi
      snapshots_found=true
    fi
  done < "$config_file"
  
  if [[ "$snapshots_found" == false ]]; then
    echo "  No snapshots"
  fi
  
  echo
done