# ArgoCD - Enterprise GitOps Platform

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. This deployment follows big tech best practices with High Availability, proper RBAC, monitoring integration, and enterprise-grade configuration.

## Overview

**What is ArgoCD?**
- Declarative GitOps CD for Kubernetes
- Application definitions, configurations, and environments are declarative and version controlled
- Application deployment and lifecycle management is automated, auditable, and easy to understand
- Supports Helm, Kustomize, Jsonnet, plain YAML/JSON manifests
- Multi-cluster management
- SSO Integration (OIDC, SAML, LDAP)
- RBAC for multi-tenancy
- Automated drift detection and remediation

## Architecture

This deployment includes:
- **High Availability**: Multiple replicas for server, repo-server, and applicationset-controller
- **LoadBalancer**: Dedicated external IP (192.168.0.215) via MetalLB
- **Ingress**: Alternative access via nginx-ingress (argocd.local)
- **RBAC**: Three-tier role model (admin, developer, readonly)
- **Monitoring**: Prometheus metrics endpoints
- **Network Policies**: Security policies for pod communication
- **Enterprise ConfigMaps**: Optimized settings for performance and scalability

## Deployment Information

**Namespace:** `argocd`
**Version:** v2.13.2 (latest stable)

**Components:**
- **Application Controller** (1 replica) - Monitors running applications and compares current state vs desired state
- **Server** (2 replicas, HA) - API server and Web UI
- **Repo Server** (2 replicas, HA) - Maintains local cache of Git repositories
- **ApplicationSet Controller** (2 replicas, HA) - Automates generation of ArgoCD Applications
- **Dex Server** (1 replica) - Identity provider for SSO
- **Redis** (1 replica) - Caching and message broker
- **Notifications Controller** (1 replica) - Sends notifications about application events

## Installation

### Quick Install

```bash
cd /repos/devops-lab-new/k8s-local/cluster_deployments/argocd
./install.sh
```

The script will:
1. Create the argocd namespace
2. Install ArgoCD v2.13.2
3. Apply HA configuration (2 replicas for critical components)
4. Configure LoadBalancer with MetalLB IP (192.168.0.215)
5. Set up Ingress for alternative access
6. Apply enterprise ConfigMaps
7. Display access information and initial admin password

### Manual Installation

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml

# Apply HA patches
kubectl patch deployment argocd-server -n argocd --patch-file ha-patch.yaml
kubectl patch deployment argocd-repo-server -n argocd --patch-file ha-patch-repo.yaml
kubectl patch deployment argocd-applicationset-controller -n argocd --patch-file ha-patch-appset.yaml

# Apply LoadBalancer
kubectl apply -f argocd-server-lb.yaml

# Apply Ingress
kubectl apply -f ingress.yaml

# Apply enterprise ConfigMaps
kubectl apply -f argocd-cmd-params-cm.yaml
kubectl apply -f argocd-cm.yaml
kubectl apply -f argocd-rbac-cm.yaml

# Restart to apply configs
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout restart deployment argocd-repo-server -n argocd
```

## Accessing ArgoCD

### Primary Access (Recommended)
**Via Ingress:**
```
http://192.168.0.210
```
Access through nginx ingress controller (no hostname configuration needed).

**Via Dedicated LoadBalancer:**
```
https://192.168.0.215
```
Direct access via MetalLB LoadBalancer IP.

### Alternative Access
**Hostname-based (requires /etc/hosts):**
```
http://argocd.local
```
Add to `/etc/hosts`:
```
192.168.0.210   argocd.local
```

**Port Forward (local development):**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080
```

### Initial Login

**Username:** `admin`

**Password:** Retrieved automatically during installation, or get it manually:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**IMPORTANT:** Change the admin password immediately after first login!

## ArgoCD CLI

### Installation

```bash
# Download latest version
VERSION="v2.13.2"
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64

# Make executable
chmod +x argocd

# Move to system path
sudo mv argocd /usr/local/bin/

# Verify
argocd version --client
```

### CLI Login

```bash
# Via LoadBalancer
argocd login 192.168.0.215 --insecure

# Via Ingress
argocd login 192.168.0.210 --insecure --grpc-web

# Change admin password
argocd account update-password
```

## Enterprise Best Practices Implemented

### 1. App of Apps Pattern

Manage all applications through ArgoCD itself:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/gitops-repo
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 2. ApplicationSets for Multi-Environment

Automatically generate applications for multiple environments:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: dev
        url: https://dev.k8s.local
      - cluster: staging
        url: https://staging.k8s.local
      - cluster: prod
        url: https://prod.k8s.local
  template:
    metadata:
      name: '{{cluster}}-app'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/app
        targetRevision: HEAD
        path: 'manifests/{{cluster}}'
      destination:
        server: '{{url}}'
        namespace: app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### 3. Projects for Multi-Tenancy

Isolate teams and applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  description: Team A Applications
  sourceRepos:
  - 'https://github.com/your-org/team-a-*'
  destinations:
  - namespace: 'team-a-*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  namespaceResourceWhitelist:
  - group: 'apps'
    kind: Deployment
  - group: ''
    kind: Service
```

### 4. RBAC Configuration

Three-tier role model configured in `argocd-rbac-cm.yaml`:
- **Admin**: Full access
- **Developer**: Deploy and sync applications
- **Readonly**: View-only access

### 5. Automated Sync Policies

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Automatically sync when cluster state deviates
    allowEmpty: false
  syncOptions:
  - Validate=true
  - CreateNamespace=true
  - PrunePropagationPolicy=foreground
  - PruneLast=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### 6. Notifications

Configure Slack, email, webhooks for deployment notifications (see `argocd-notifications-cm` ConfigMap).

## Configuration Files

### Main ConfigMaps

**argocd-cm.yaml** - Core ArgoCD configuration:
- Git repository timeout settings
- Resource tracking method
- UI customization
- Helm repositories
- Resource exclusions and customizations

**argocd-cmd-params-cm.yaml** - Command parameters:
- Server insecure mode
- Application namespace settings
- Timeout configurations
- Parallelism limits
- Controller processors

**argocd-rbac-cm.yaml** - RBAC policies:
- Role definitions (admin, developer, readonly)
- Policy CSV for access control
- Default policy
- Group mappings

## Monitoring and Observability

### Prometheus Metrics

ArgoCD exposes metrics on these endpoints:
- `argocd-metrics:8082` - Application controller
- `argocd-server-metrics:8083` - API server
- `argocd-repo-server:8084` - Repository server

### ServiceMonitor (for Prometheus Operator)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
```

### Key Metrics to Monitor

- `argocd_app_info` - Application metadata
- `argocd_app_sync_total` - Sync operation count
- `argocd_app_k8s_request_total` - Kubernetes API requests
- `argocd_redis_request_duration` - Redis latency
- `argocd_git_request_duration_seconds` - Git operation duration

## Common Operations

### Create Application

```bash
argocd app create myapp \
  --repo https://github.com/your-org/repo.git \
  --path manifests/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

### Sync Application

```bash
# Sync single app
argocd app sync myapp

# Sync all apps
argocd app sync --all

# Force sync (ignore differences)
argocd app sync myapp --force
```

### View Application Status

```bash
# List all applications
argocd app list

# Get application details
argocd app get myapp

# View application diff
argocd app diff myapp

# View application history
argocd app history myapp
```

### Rollback Application

```bash
# List history
argocd app history myapp

# Rollback to specific revision
argocd app rollback myapp <revision-id>
```

### Add Git Repository

```bash
# HTTPS with token
argocd repo add https://github.com/your-org/repo.git \
  --username git \
  --password <github-token>

# SSH
argocd repo add git@github.com:your-org/repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### Add Helm Repository

```bash
argocd repo add https://charts.helm.sh/stable \
  --type helm \
  --name stable
```

### Manage Clusters

```bash
# List clusters
argocd cluster list

# Add external cluster
argocd cluster add <context-name>

# Remove cluster
argocd cluster rm <server-url>
```

## Security

### Change Admin Password

Via CLI:
```bash
argocd account update-password
```

Via kubectl:
```bash
# Create bcrypt hash of new password
htpasswd -nbBC 10 "" <new-password> | tr -d ':\n' | sed 's/$2y/$2a/'

# Update secret
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "<bcrypt-hash>", "admin.passwordMtime": "'$(date +%FT%T%Z)'"}}'
```

### Enable SSO (OIDC)

Edit `argocd-cm` ConfigMap:

```yaml
data:
  url: https://argocd.yourdomain.com
  oidc.config: |
    name: Google
    issuer: https://accounts.google.com
    clientID: <client-id>
    clientSecret: $oidc.google.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
```

### Create Local Users

```bash
# Add user to argocd-cm ConfigMap
kubectl patch cm argocd-cm -n argocd --type merge -p '
  data:
    accounts.alice: apiKey, login
    accounts.bob: apiKey
'

# Set password
argocd account update-password --account alice
```

## Troubleshooting

### Application Stuck in Progressing

```bash
# View events
kubectl describe application myapp -n argocd

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller -f

# Force refresh
argocd app get myapp --refresh --hard-refresh
```

### Sync Fails

```bash
# View diff
argocd app diff myapp

# Check sync status
argocd app get myapp

# Manual sync with prune
argocd app sync myapp --prune
```

### Repository Connection Issues

```bash
# Test repository connection
argocd repo list

# Check repo-server logs
kubectl logs -n argocd deployment/argocd-repo-server -f

# Remove and re-add repository
argocd repo rm https://github.com/your-org/repo.git
argocd repo add https://github.com/your-org/repo.git --username <user> --password <token>
```

### Performance Issues

```bash
# Scale replicas
kubectl scale deployment argocd-server -n argocd --replicas=3
kubectl scale deployment argocd-repo-server -n argocd --replicas=3

# Check resource usage
kubectl top pods -n argocd

# Increase controller processors
kubectl patch cm argocd-cmd-params-cm -n argocd --type merge -p '
  data:
    controller.status.processors: "30"
    controller.operation.processors: "15"
'
```

## Backup and Disaster Recovery

### Backup

```bash
# Backup all ArgoCD resources
kubectl get applications,appprojects,configmaps,secrets -n argocd -o yaml > argocd-backup.yaml

# Backup specific components
kubectl get applications -n argocd -o yaml > apps.yaml
kubectl get appprojects -n argocd -o yaml > projects.yaml
```

### Restore

```bash
# Restore applications
kubectl apply -f argocd-backup.yaml

# Or restore selectively
kubectl apply -f apps.yaml
kubectl apply -f projects.yaml
```

## Uninstallation

```bash
./uninstall.sh
```

Or manually:
```bash
kubectl delete namespace argocd
```

## File Structure

```
argocd/
├── README.md                    # This file
├── ACCESS-INFO.md               # Quick access reference
├── namespace.yaml               # Namespace definition
├── install.sh                   # Installation script
├── uninstall.sh                 # Uninstallation script
├── argocd-server-lb.yaml        # LoadBalancer service (192.168.0.215)
├── ingress.yaml                 # Ingress resource
├── ha-patch.yaml                # HA patch for server
├── ha-patch-repo.yaml           # HA patch for repo-server
├── ha-patch-appset.yaml         # HA patch for applicationset-controller
├── argocd-cm.yaml               # Core configuration
├── argocd-cmd-params-cm.yaml    # Command parameters
└── argocd-rbac-cm.yaml          # RBAC policies
```

## Additional Resources

- **Official Documentation:** https://argo-cd.readthedocs.io/
- **GitHub:** https://github.com/argoproj/argo-cd
- **Best Practices:** https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/
- **Slack:** https://argoproj.github.io/community/join-slack/
- **Examples:** https://github.com/argoproj/argocd-example-apps

## Next Steps

1. **Change admin password** immediately
2. **Add your Git repositories** containing Kubernetes manifests
3. **Create applications** to deploy your workloads
4. **Set up RBAC** for your team members
5. **Configure SSO** for enterprise authentication
6. **Enable notifications** for deployment events
7. **Set up monitoring** with Prometheus/Grafana
8. **Implement App of Apps** pattern for managing all applications
9. **Create AppProjects** for multi-tenancy
10. **Configure backup** strategy

## Notes

- ArgoCD follows GitOps principles - Git is the single source of truth
- All changes should be made via Git commits, not kubectl
- Use automated sync policies for continuous deployment
- Implement proper Git branching strategy (e.g., GitFlow)
- Use separate repositories or branches for different environments
- Leverage Kustomize or Helm for environment-specific configurations
- Monitor sync status and set up alerts for failed deployments
- Regular backups of ArgoCD configuration and application definitions
- Keep ArgoCD updated to latest stable version for security and features
