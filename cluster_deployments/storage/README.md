# Kubernetes Storage Provisioning

This directory contains storage provider manifests and Helm configurations used to provision persistent storage for the lab clusters. Each subdirectory is self-contained and can be applied independently, depending on the backing storage available in the environment.

## Available Providers

| Provider    | Use Case                                    | Notes |
|-------------|---------------------------------------------|-------|
| `local-path` | Single-node or developer clusters           | Deploys Rancher Local Path Provisioner with a non-default storage class. |
| `nfs`        | Shared storage backed by an existing NFS share | Requires an accessible NFS server and path. |
| `longhorn`   | Distributed block storage with a UI and HA options | Installs Longhorn via Helm and provides an extra HA storage class. |

## Usage

### Local Path Provisioner

```bash
kubectl apply -f local-path/local-path-provisioner.yaml
kubectl apply -f local-path/storageclass.yaml
```

The manifest creates the `local-path-storage` namespace, RBAC, and a `local-path` storage class (non-default). Adjust the host path in the ConfigMap if worker nodes use a different filesystem layout.

### NFS Subdir External Provisioner

1. Update the NFS endpoint in `nfs/nfs-subdir-external-provisioner.yaml`:
   - `NFS_SERVER`
   - `NFS_PATH`
2. Deploy the provisioner and storage class:

```bash
kubectl apply -f nfs/nfs-subdir-external-provisioner.yaml
kubectl apply -f nfs/storageclass.yaml
```

The `nfs-storage` class uses immediate volume binding and keeps PVC data when deleted. Set `archiveOnDelete: "true"` to retain subdirectories after PVC deletion.

### Longhorn

Longhorn is installed through Helm with opinionated defaults for lab usage.

```bash
cd longhorn
./install.sh
```

The installer:
- Adds the Longhorn Helm repository and installs the chart into `longhorn-system`
- Waits for core components to become ready
- Applies `storageclasses.yaml` to add the optional `longhorn-ha` storage class (non-default, replica count 2)

Review `longhorn/values.yaml` before installation to adjust:
- Ingress host (`longhorn.local`) and annotations
- Replica count and data locality defaults
- Default data path on worker nodes

After deployment, verify the classes:

```bash
kubectl get storageclass | grep longhorn
```

To make Longhorn the cluster default storage class:

```bash
kubectl patch storageclass longhorn \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Validation

1. Create a test PersistentVolumeClaim (example below uses the `longhorn-ha` class):

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: storage-smoke-test
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 2Gi
     storageClassName: longhorn-ha
   ```

   Save as `pvc-smoke-test.yaml` and apply with `kubectl apply -f pvc-smoke-test.yaml`.
2. Confirm provisioning finishes: `kubectl get pvc,pv`
3. Inspect provisioner logs if provisioning fails:
   - `kubectl logs -n local-path-storage deploy/local-path-provisioner`
   - `kubectl logs -n nfs-provisioner deploy/nfs-subdir-external-provisioner`
   - `kubectl -n longhorn-system logs -l app=longhorn-manager`

Keep manifests free of credentials—mount secrets from `vagrant/creds.yml` or Vault when necessary.
