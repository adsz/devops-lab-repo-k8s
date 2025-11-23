# Development Roadmap: k8s-local

Based on the analysis of the current repository state and broader infrastructure context, here is a proposed roadmap for the evolution of the `k8s-local` cluster.

## 1. Stability & Infrastructure (High Priority)

The current cluster is running with a workaround (direct connection to master) due to HAProxy VIP timeout issues.

*   **[CRITICAL] Fix HAProxy VIP Timeout**:
    *   **Problem**: `k8s-api` traffic via VIP `192.168.0.150` times out, forcing use of `192.168.0.180` (SPOF).
    *   **Action**: Debug HAProxy configuration (likely in `svc-load-balancer` or `ansible-central`). Check timeouts, health checks, and backend connectivity.
    *   **Goal**: Re-enable `control_plane_endpoint: "k8s-api.devops-lab.cloud:6443"` in Ansible.

*   **Enable High Availability (HA)**:
    *   **Current**: 2 Masters defined in inventory (`192.168.0.180`, `192.168.0.181`), but direct connection only targets one.
    *   **Action**: Once VIP is fixed, ensure both masters are active backends in HAProxy.

## 2. Upgrades & Maintenance

Current Version: `1.29.15` (Calico `v3.27.3`)

*   **Upgrade to Kubernetes v1.30+**:
    *   **Action**: Update `kubernetes_version` in `roles/k8s-master/defaults/main.yml` and `roles/k8s-worker/defaults/main.yml`.
    *   **Plan**: Test upgrade procedure in `cluster_upgrade/UPGRADE-PLAN.md`.

*   **Automate OS Patching**:
    *   **Action**: Implement automated OS updates for the Ubuntu 22.04 nodes (e.g., via Ansible or unattended-upgrades).

## 3. Modernization & GitOps (Big Tech Standards)

To align with the "Big Tech" standards observed in other repositories (`bam`):

*   **Implement ArgoCD**:
    *   **Current**: `cluster_deployments` contains raw manifests/scripts.
    *   **Action**: Deploy ArgoCD and manage these add-ons via GitOps.
    *   **Benefit**: Automated drift detection, easier management, better visibility.

*   **Standardize Ingress**:
    *   **Current**: `nginx-ingress` is present.
    *   **Action**: Ensure it's integrated with `cert-manager` for automated TLS (Let's Encrypt) and potentially external DNS if applicable (though local).

## 4. Observability

*   **Enhance Monitoring**:
    *   **Current**: `prometheus-stack`.
    *   **Action**: Verify alerts are routing correctly (e.g., to Slack/Discord). Add **Loki** for centralized logging to match the ELK stack mentioned in broader docs (or integrate with existing ELK).

## 5. Disaster Recovery (DR)

*   **Validate DR Plan**:
    *   **Action**: Execute a "fire drill" based on `DISASTER-RECOVERY-GUIDE.md`.
    *   **Goal**: Confirm that `velero` backups can successfully restore the cluster state from scratch.

## Summary of Recommended Next Steps

1.  **Fix HAProxy VIP** (Prerequisite for true HA).
2.  **Deploy ArgoCD** (Modernize deployment workflow).
3.  **Upgrade to K8s v1.30** (Keep current).
