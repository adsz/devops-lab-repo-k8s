# Longhorn Distributed Storage

Longhorn provides replicated block storage for Kubernetes. This directory contains installation assets tailored for the `devops-lab` clusters.

## Components

- `install.sh` – Helm-based installer that sets up Longhorn in `longhorn-system`, waits for core workloads, and applies extra storage classes.
- `values.yaml` – Opinionated overrides for the Helm chart (HA defaults, ingress, data path).
- `storageclasses.yaml` – Adds the optional `longhorn-ha` storage class with two replicas and best-effort data locality.

## Installation

```bash
cd /repos/devops-lab-new/k8s-local/cluster_deployments/storage/longhorn
./install.sh
```

The script:
1. Validates that `kubectl` and `helm` are available and the cluster is reachable.
2. Adds the upstream Longhorn Helm repository (https://charts.longhorn.io) and updates repo indices.
3. Installs or upgrades the `longhorn` release with the supplied `values.yaml`.
4. Waits for `longhorn-driver-deployer` and `longhorn-manager` to finish rolling out.
5. Applies `storageclasses.yaml` to register the `longhorn-ha` storage class.

## Customisation

- **Ingress host:** Update `longhorn.local` in `values.yaml` to match your DNS or `/etc/hosts` entry. Toggle TLS by enabling `ingress.tls` and referencing a secret.
- **Replica count & locality:** Tune `persistence.defaultClassReplicaCount`, `persistence.defaultDataLocality`, and `defaultSettings.defaultReplicaCount` to match available worker nodes.
- **Data path:** Ensure `/var/lib/longhorn` (default) has sufficient capacity on each node or change `defaultSettings.defaultDataPath`.
- **Default storage class:** Patch the generated `longhorn` StorageClass if you want it to become the cluster default (see parent `README.md`).

## Removal

```bash
helm uninstall longhorn -n longhorn-system
kubectl delete -f storageclasses.yaml
```

Volumes created by Longhorn persist until you delete the related PVCs. Consider migrating workloads before uninstalling in production environments.
