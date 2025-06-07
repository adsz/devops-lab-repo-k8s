#!/bin/bash

# Variables
VM_NAME="$1"
SNAPSHOT_NAME="$2"

# Check if VirtualBox is installed
if ! command -v VBoxManage &> /dev/null; then
    echo "Error: VirtualBox is not installed or VBoxManage is not in PATH."
    exit 1
fi

# Check if VM exists
if ! VBoxManage showvminfo "$VM_NAME" &> /dev/null; then
    echo "Error: VM '$VM_NAME' does not exist."
    exit 1
fi

# Check if VM is running
VM_STATE=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep '^VMState=' | cut -d'"' -f2)
if [ "$VM_STATE" = "running" ]; then
    echo "Shutting down VM '$VM_NAME' gracefully..."
    VBoxManage controlvm "$VM_NAME" acpipowerbutton
    if [ $? -ne 0 ]; then
        echo "Error: Failed to initiate graceful shutdown for VM '$VM_NAME'."
        exit 1
    fi

    # Wait for VM to shut down (up to 60 seconds)
    echo "Waiting for VM to shut down..."
    TIMEOUT=60
    ELAPSED=0
    while [ "$VM_STATE" = "running" ] && [ $ELAPSED -lt $TIMEOUT ]; do
        sleep 5
        VM_STATE=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep '^VMState=' | cut -d'"' -f2)
        ELAPSED=$((ELAPSED + 5))
    done

    if [ "$VM_STATE" = "running" ]; then
        echo "Error: VM '$VM_NAME' did not shut down within $TIMEOUT seconds."
        exit 1
    fi
else
    echo "VM '$VM_NAME' is already stopped."
fi

# Restore the snapshot
echo "Restoring snapshot '$SNAPSHOT_NAME' for VM '$VM_NAME'..."
VBoxManage snapshot "$VM_NAME" restore "$SNAPSHOT_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to restore snapshot '$SNAPSHOT_NAME'."
    exit 1
fi

# Start the VM
echo "Starting VM '$VM_NAME'..."
VBoxManage startvm "$VM_NAME" --type headless
if [ $? -ne 0 ]; then
    echo "Error: Failed to start VM '$VM_NAME'."
    exit 1
fi

echo "VM '$VM_NAME' has been stopped, restored to snapshot '$SNAPSHOT_NAME', and started successfully."
