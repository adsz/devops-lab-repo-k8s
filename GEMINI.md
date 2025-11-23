# Project Overview

This directory contains a local Kubernetes lab environment based on Vagrant and Ansible. It is designed to provision a Kubernetes cluster on local virtual machines (likely using VirtualBox) and deploy a set of standard services and applications.

## Directory Structure

*   **`ubuntu-22.04`**: Core infrastructure code. Contains Vagrantfiles and Ansible playbooks to provision Ubuntu 22.04 VMs and install Kubernetes components.
*   **`cluster_deployments`**: Configuration and manifests for system-level services and add-ons, including:
    *   `cert-manager`: Certificate management.
    *   `metallb`: Bare-metal load balancer.
    *   `prometheus-stack`: Monitoring and alerting (Prometheus, Grafana).
    *   `velero`: Backup and disaster recovery.
    *   `storage`: Storage class configurations.
    *   `nginx-ingress`: Ingress controller.
*   **`apps_deployments`**: Deployment manifests for example applications (e.g., `demo-nginx`).
*   **`cluster_upgrade`**: Documentation and scripts related to cluster upgrades (`UPGRADE-PLAN.md`).
*   **`docs`**: Operational documentation, including disaster recovery guides and load balancer configurations.

## Dependencies

To work with this repository, the following tools are likely required:

*   **Vagrant**: For managing the virtual machine lifecycle.
*   **VirtualBox**: The likely hypervisor for Vagrant.
*   **Ansible**: For configuration management and provisioning of the VMs.
*   **kubectl**: For interacting with the Kubernetes cluster.
*   **Helm**: Likely used for deploying charts in `cluster_deployments`.

## Key Files

*   **`howto.md`**: (Local only) Likely contains specific instructions for setting up and running the lab.
*   **`UPGRADE-PLAN.md`**: Detailed plan for upgrading the cluster.
*   **`DISASTER-RECOVERY-GUIDE.md`**: Guide for restoring the cluster in case of failure.

# Broader Context (from `/root/docs`)

This repository (`k8s-local`) is part of a larger "DevOps Lab" infrastructure. Key integration points include:

*   **Networking**: The cluster operates on the local network (`192.168.0.x`).
*   **Load Balancing**:
    *   Historically used a dedicated VM (`192.168.0.175`).
    *   Migrated to a centralized HAProxy VIP (`192.168.0.150`) for better availability.
    *   *Note:* As of Nov 2025, nodes may use direct master connection (`192.168.0.180:6443`) due to VIP timeout issues.
*   **Nodes**: The cluster typically consists of 3 nodes: `master-1`, `worker-1`, `worker-2`.
*   **Documentation**:
    *   `INFRASTRUCTURE-OVERVIEW.md` (in `/root/docs`): Contains the high-level map of the entire lab, including this cluster's status and known issues.
    *   `EKS-CONSOLE-ACCESS-FIX.md`: Relevant for EKS clusters in the lab, though `k8s-local` is on-prem.

## Known Issues (Historical)
*   **Worker-2 Failure**: Caused by incorrect API server configuration (pointing to non-existent VIP). Fixed by reverting to direct master connection.
