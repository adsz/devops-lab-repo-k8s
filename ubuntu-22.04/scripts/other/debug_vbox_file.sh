#!/bin/bash
# File: scripts/debug_vbox_file.sh

VM="k8s-lb"

echo "=== Checking .vbox file for snapshot timestamps ==="

# Get the config file path
config_file=$(VBoxManage showvminfo "$VM" --machinereadable | grep "CfgFile=" | cut -d'"' -f2)

echo "Config file: $config_file"

if [[ -f "$config_file" ]]; then
  echo -e "\nSnapshot entries in .vbox file:"
  grep -A5 -B5 "timeStamp\|Snapshot.*uuid" "$config_file"
else
  echo "Config file not found"
fi