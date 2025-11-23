# Kubeshark - Network Observability for Kubernetes

Kubeshark is an API traffic analyzer for Kubernetes providing real-time protocol-level visibility, capturing and monitoring all traffic and payloads going in, out, and across containers, pods, nodes, and clusters.

## Overview

**What is Kubeshark?**
- Network traffic analyzer specifically designed for Kubernetes (Wireshark for K8s)
- Real-time API traffic monitoring and analysis
- Protocol-level visibility for HTTP, gRPC, REST, GraphQL, Kafka, Redis, and more
- Service mesh visibility without requiring sidecars
- Troubleshooting and debugging network issues in real-time

## Deployment Information

**Namespace:** `kubeshark`

**Components:**
- `kubeshark-front` - Web-based dashboard (nginx frontend)
- `kubeshark-hub` - Central data aggregation and processing
- `kubeshark-worker-daemon-set` - Traffic capture agents (runs on each node)

**Resources:**
- Chart Version: 52.9.0
- Image Registry: docker.io/kubeshark
- Helm Release: kubeshark

## Installation

### Prerequisites
- Kubernetes cluster (v1.19+)
- Helm 3.x
- kubectl configured to access the cluster
- Sufficient resources on worker nodes for DaemonSet

### Quick Install

```bash
cd /repos/devops-lab-new/k8s-local/cluster_deployments/kubeshark
./install.sh
```

The install script will:
1. Create the `kubeshark` namespace
2. Add the Kubeshark Helm repository
3. Install Kubeshark with custom values
4. Wait for all pods to become ready

### Manual Installation

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Add Helm repository
helm repo add kubeshark https://helm.kubeshark.co
helm repo update

# Install with custom values
helm install kubeshark kubeshark/kubeshark \
    --namespace kubeshark \
    --values values.yaml
```

## Accessing the Dashboard

### Method 1: External Access via Ingress (Recommended)

Kubeshark is already configured with Ingress for external access!

**Access URL:** http://192.168.0.210

You can also use the hostname (requires DNS or /etc/hosts entry):
- **URL:** http://kubeshark.local
- **Ingress IP:** 192.168.0.210

To add hostname resolution on your local machine:

```bash
# Add to /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
192.168.0.210   kubeshark.local
```

**Testing access:**
```bash
curl -I http://192.168.0.210 -H "Host: kubeshark.local"
# Or simply open in browser: http://192.168.0.210
```

**Ingress Configuration:**
- IngressClass: nginx
- Host: kubeshark.local (with wildcard fallback)
- Service: kubeshark-front:80
- Backend: 10.244.230.24:8080

### Method 2: Port Forward (For Local Development)

Use the provided access script:

```bash
./access.sh
```

Or manually:

```bash
kubectl port-forward -n kubeshark svc/kubeshark-front 8899:80
```

Then open your browser: http://localhost:8899

### Method 3: Custom Domain with TLS (Production)

Edit `ingress.yaml` to add your domain and TLS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubeshark-ingress
  namespace: kubeshark
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - kubeshark.devops-lab.cloud
      secretName: kubeshark-tls
  rules:
    - host: kubeshark.devops-lab.cloud
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubeshark-front
                port:
                  number: 80
```

Then apply:

```bash
kubectl apply -f ingress.yaml
```

## Configuration

### Main Configuration File

`values.yaml` - Helm chart values configuration

**Key settings:**
- `tap.namespaces` - List of namespaces to monitor (empty = all)
- `tap.resources` - Resource limits for workers and hub
- `storage.enabled` - Enable persistent storage for captures
- `storage.size` - Storage size for traffic data
- `ingress.enabled` - Enable ingress for external access

### Monitoring Specific Namespaces

Edit `values.yaml`:

```yaml
tap:
  namespaces:
    - default
    - production
    - staging
```

### Resource Limits

Adjust based on cluster size and traffic volume:

```yaml
tap:
  resources:
    worker:
      limits:
        cpu: 1000m
        memory: 2Gi
      requests:
        cpu: 100m
        memory: 128Mi
```

## Usage Examples

### View All Traffic

Access the dashboard and observe real-time traffic across all monitored namespaces.

### Filter Traffic

Use the dashboard query language:
- Filter by namespace: `kubernetes.namespace == "default"`
- Filter by service: `kubernetes.serviceName == "nginx"`
- Filter by HTTP method: `http.request.method == "POST"`
- Filter by response code: `http.response.statusCode >= 400`

### Troubleshooting Network Issues

1. Access the dashboard
2. Filter traffic by the problematic service
3. Inspect request/response payloads
4. Check latency and error rates
5. Analyze protocol-specific issues

### Export Traffic Data

Kubeshark allows exporting captured traffic for offline analysis or compliance purposes.

## Operational Commands

### Check Status

```bash
kubectl get all -n kubeshark
```

### View Logs

```bash
# Hub logs
kubectl logs -n kubeshark deployment/kubeshark-hub -f

# Frontend logs
kubectl logs -n kubeshark deployment/kubeshark-front -f

# Worker logs (on specific node)
kubectl logs -n kubeshark daemonset/kubeshark-worker-daemon-set -f
```

### Restart Components

```bash
# Restart hub
kubectl rollout restart deployment/kubeshark-hub -n kubeshark

# Restart frontend
kubectl rollout restart deployment/kubeshark-front -n kubeshark

# Restart workers
kubectl rollout restart daemonset/kubeshark-worker-daemon-set -n kubeshark
```

### Update Configuration

Edit `values.yaml` and apply changes:

```bash
helm upgrade kubeshark kubeshark/kubeshark \
    --namespace kubeshark \
    --values values.yaml
```

## Uninstallation

### Quick Uninstall

```bash
./uninstall.sh
```

### Manual Uninstall

```bash
# Remove Helm release
helm uninstall kubeshark -n kubeshark

# Delete namespace
kubectl delete namespace kubeshark
```

## Security Considerations

### Required Permissions

Kubeshark requires privileged access to capture network traffic:
- `NET_RAW` and `NET_ADMIN` capabilities
- Access to host network interfaces
- RBAC permissions to list pods and services

### Network Policies

If using network policies, ensure Kubeshark workers can communicate with the hub:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-kubeshark
  namespace: kubeshark
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: kubeshark
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: kubeshark
```

### Data Privacy

**Important:** Kubeshark captures full request/response payloads including:
- API keys and tokens in headers
- Sensitive data in request/response bodies
- Database queries and results

**Recommendations:**
- Enable persistent storage encryption
- Restrict dashboard access using ingress authentication
- Use namespace filtering to avoid capturing sensitive traffic
- Implement proper RBAC policies
- Consider data retention policies

## License

Kubeshark offers both open-source and enterprise versions. The open-source version is available under Apache 2.0 license. Enterprise features require a license key from https://console.kubeshark.co/

To add a license:

```bash
helm upgrade kubeshark kubeshark/kubeshark \
    --namespace kubeshark \
    --values values.yaml \
    --set license=YOUR_LICENSE_KEY
```

## Troubleshooting

### Pods Not Starting

Check pod status and events:

```bash
kubectl describe pod -n kubeshark -l app.kubernetes.io/name=kubeshark
```

Common issues:
- Insufficient node resources
- Missing NET_RAW/NET_ADMIN capabilities
- Security context constraints (on OpenShift)

### No Traffic Visible

Verify:
1. Worker DaemonSet is running on all nodes
2. Target pods are in monitored namespaces
3. Dashboard filters are not too restrictive
4. Service mesh compatibility (if applicable)

### High Resource Usage

Adjust resource limits in `values.yaml` or reduce monitored namespaces:

```yaml
tap:
  namespaces:
    - production  # Monitor only production namespace
```

### Dashboard Not Accessible

Check service and port-forward:

```bash
kubectl get svc -n kubeshark
kubectl port-forward -n kubeshark svc/kubeshark-front 8899:80
```

## Integration

### Prometheus Metrics

Kubeshark exposes Prometheus metrics:
- `kubeshark-hub-metrics:9100`
- `kubeshark-worker-metrics:49100`

Add ServiceMonitor for Prometheus Operator:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kubeshark-metrics
  namespace: kubeshark
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kubeshark
  endpoints:
    - port: metrics
      interval: 30s
```

### Grafana Dashboards

Import Kubeshark dashboards from Grafana.com or create custom dashboards using metrics.

### Alerting

Configure alerts based on traffic patterns:
- High error rates (4xx/5xx responses)
- Increased latency
- Unusual traffic patterns
- Protocol errors

## Additional Resources

- **Official Documentation:** https://docs.kubeshark.co/
- **GitHub Repository:** https://github.com/kubeshark/kubeshark
- **Helm Chart:** https://github.com/kubeshark/kubeshark-helm-charts
- **Community Support:** Discord and Slack channels
- **Tutorial:** https://www.kubeshark.co/post/kubeshark-tutorial-developer-track

## File Structure

```
kubeshark/
├── README.md           # This file
├── namespace.yaml      # Namespace definition
├── values.yaml         # Helm chart values
├── ingress.yaml        # Ingress resource for external access
├── install.sh          # Installation script
├── uninstall.sh        # Uninstallation script
└── access.sh           # Dashboard access helper (port-forward)
```

## Notes

- Kubeshark is designed for observability and troubleshooting, not long-term traffic storage
- Consider using persistent storage for critical environments
- Monitor resource consumption on nodes running worker DaemonSet
- Regular updates recommended for security and feature improvements
