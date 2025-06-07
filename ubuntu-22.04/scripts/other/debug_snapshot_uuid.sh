#!/bin/bash
# File: scripts/debug_snapshot_uuid.sh

VM="k8s-lb"

echo "=== Testing snapshot info with UUID ==="

echo "1. Testing with first snapshot UUID:"
VBoxManage snapshot "$VM" showvminfo "1174b331-c0b1-4939-a663-543df6296ca1"

echo -e "\n2. Testing with second snapshot UUID:"
VBoxManage snapshot "$VM" showvminfo "c0d4e870-5fd2-4b78-9b68-ddf1f5be1c48"