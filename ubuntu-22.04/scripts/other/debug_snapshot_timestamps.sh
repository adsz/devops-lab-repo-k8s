#!/bin/bash
# File: scripts/debug_snapshot_timestamps.sh

VM="k8s-lb"
SNAPSHOT="After installation from Vagrant"

echo "=== Testing VirtualBox snapshot timestamp commands ==="

echo "1. Testing: VBoxManage snapshot list --machinereadable"
VBoxManage snapshot "$VM" list --machinereadable

echo -e "\n2. Testing: VBoxManage snapshot showvminfo for specific snapshot"
VBoxManage snapshot "$VM" showvminfo "$SNAPSHOT"

echo -e "\n3. Testing: VBoxManage showvminfo --machinereadable"
VBoxManage showvminfo "$VM" --machinereadable | grep -i snapshot