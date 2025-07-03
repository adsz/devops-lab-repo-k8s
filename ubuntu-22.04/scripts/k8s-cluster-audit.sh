#!/bin/bash
# k8s-cluster-audit.sh
# Comprehensive Kubernetes cluster audit for microservices readiness

set -euo pipefail
unset KUBECONFIG

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Icons
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
AUDIT_REPORT="/tmp/k8s_audit_report_${TIMESTAMP}.txt"
JSON_REPORT="/tmp/k8s_audit_report_${TIMESTAMP}.json"

# Initialize JSON report
echo '{"timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "cluster_audit": {}}' > "$JSON_REPORT"

# Logging functions
log_info() {
    echo -e "${BLUE}${INFO} ${NC}$1" | tee -a "$AUDIT_REPORT"
}

log_success() {
    echo -e "${GREEN}${CHECK} ${NC}$1" | tee -a "$AUDIT_REPORT"
}

log_warning() {
    echo -e "${YELLOW}${WARNING} ${NC}$1" | tee -a "$AUDIT_REPORT"
}

log_error() {
    echo -e "${RED}${CROSS} ${NC}$1" | tee -a "$AUDIT_REPORT"
}

log_header() {
    echo -e "\n${PURPLE}${ROCKET} $1${NC}" | tee -a "$AUDIT_REPORT"
    echo "$(printf '=%.0s' {1..60})" | tee -a "$AUDIT_REPORT"
}

# JSON helper functions
update_json() {
    local key="$1"
    local value="$2"
    local type="${3:-string}"
    
    if [[ "$type" == "object" ]]; then
        jq --arg key "$key" --argjson value "$value" '.cluster_audit[$key] = $value' "$JSON_REPORT" > tmp.$$.json && mv tmp.$$.json "$JSON_REPORT"
    else
        jq --arg key "$key" --arg value "$value" '.cluster_audit[$key] = $value' "$JSON_REPORT" > tmp.$$.json && mv tmp.$$.json "$JSON_REPORT"
    fi
}

# Check if kubectl is available and configured
check_kubectl() {
    log_header "Checking kubectl availability"
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    local context=$(kubectl config current-context 2>/dev/null || echo "unknown")
    local cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "unknown")
    
    log_success "kubectl is available and configured"
    log_info "Current context: $context"
    log_info "Current cluster: $cluster"
    
    update_json "kubectl_available" "true"
    update_json "current_context" "$context"
    update_json "current_cluster" "$cluster"
}

# Check Kubernetes version
check_k8s_version() {
    log_header "Checking Kubernetes Version"
    
    local client_version=$(kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo "unknown")
    local server_version=$(kubectl version --output=json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "unknown")
    
    log_info "Client version: $client_version"
    log_info "Server version: $server_version"
    
    # Check if server version is 1.24+
    if [[ "$server_version" != "unknown" ]]; then
        local version_number=$(echo "$server_version" | sed 's/v//' | cut -d. -f1,2)
        local major=$(echo "$version_number" | cut -d. -f1)
        local minor=$(echo "$version_number" | cut -d. -f2)
        
        if [[ $major -gt 1 ]] || [[ $major -eq 1 && $minor -ge 24 ]]; then
            log_success "Kubernetes version $server_version is compatible (1.24+)"
            update_json "version_compatible" "true"
        else
            log_warning "Kubernetes version $server_version may have compatibility issues (recommended: 1.24+)"
            update_json "version_compatible" "false"
        fi
    else
        log_error "Could not determine server version"
        update_json "version_compatible" "unknown"
    fi
    
    update_json "client_version" "$client_version"
    update_json "server_version" "$server_version"
}

# Check nodes and resources
check_nodes_resources() {
    log_header "Checking Nodes and Resources"
    
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    
    log_info "Total nodes: $node_count"
    log_info "Ready nodes: $ready_nodes"
    
    if [[ $ready_nodes -eq $node_count && $node_count -gt 0 ]]; then
        log_success "All nodes are ready"
    else
        log_warning "Some nodes are not ready ($ready_nodes/$node_count)"
    fi
    
    # Detailed node information
    echo -e "\n${CYAN}Node Details:${NC}" | tee -a "$AUDIT_REPORT"
    kubectl get nodes -o wide | tee -a "$AUDIT_REPORT"
    
    # Resource utilization
    echo -e "\n${CYAN}Resource Utilization:${NC}" | tee -a "$AUDIT_REPORT"
    if kubectl top nodes &>/dev/null; then
        kubectl top nodes | tee -a "$AUDIT_REPORT"
        log_success "Metrics server is available"
        update_json "metrics_server_available" "true"
    else
        log_warning "Metrics server not available or not working"
        update_json "metrics_server_available" "false"
    fi
    
    # Node capacity
    echo -e "\n${CYAN}Node Capacity Summary:${NC}" | tee -a "$AUDIT_REPORT"
    kubectl describe nodes | grep -A 5 "Capacity:" | tee -a "$AUDIT_REPORT"
    
    update_json "total_nodes" "$node_count"
    update_json "ready_nodes" "$ready_nodes"
}

# Check storage classes
check_storage() {
    log_header "Checking Storage Classes and CSI Drivers"
    
    local storage_classes=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
    local default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null)
    
    log_info "Storage classes found: $storage_classes"
    
    if [[ $storage_classes -gt 0 ]]; then
        log_success "Storage classes are configured"
        echo -e "\n${CYAN}Available Storage Classes:${NC}" | tee -a "$AUDIT_REPORT"
        kubectl get storageclass -o wide | tee -a "$AUDIT_REPORT"
        
        if [[ -n "$default_sc" ]]; then
            log_success "Default storage class: $default_sc"
            update_json "default_storage_class" "$default_sc"
        else
            log_warning "No default storage class configured"
            update_json "default_storage_class" ""
        fi
    else
        log_error "No storage classes found"
    fi
    
    # Check for CSI drivers
    echo -e "\n${CYAN}CSI Drivers:${NC}" | tee -a "$AUDIT_REPORT"
    if kubectl get csidriver &>/dev/null; then
        kubectl get csidriver | tee -a "$AUDIT_REPORT"
        local csi_count=$(kubectl get csidriver --no-headers 2>/dev/null | wc -l)
        log_info "CSI drivers found: $csi_count"
        update_json "csi_drivers_count" "$csi_count"
    else
        log_warning "No CSI drivers found or CSI not supported"
        update_json "csi_drivers_count" "0"
    fi
    
    update_json "storage_classes_count" "$storage_classes"
}

# Check ingress controllers
check_ingress() {
    log_header "Checking Ingress Controllers"
    
    # Check for ingress classes
    local ingress_classes=$(kubectl get ingressclass --no-headers 2>/dev/null | wc -l)
    log_info "Ingress classes found: $ingress_classes"
    
    if [[ $ingress_classes -gt 0 ]]; then
        echo -e "\n${CYAN}Available Ingress Classes:${NC}" | tee -a "$AUDIT_REPORT"
        kubectl get ingressclass | tee -a "$AUDIT_REPORT"
        log_success "Ingress classes are configured"
    fi
    
    # Check for common ingress controllers
    local nginx_ingress=""
    local traefik_ingress=""
    local haproxy_ingress=""
    
    if kubectl get pods -A | grep -E "nginx.*ingress|ingress.*nginx" &>/dev/null; then
        nginx_ingress="detected"
        log_success "NGINX Ingress Controller detected"
    fi
    
    if kubectl get pods -A | grep traefik &>/dev/null; then
        traefik_ingress="detected"
        log_success "Traefik Ingress Controller detected"
    fi
    
    if kubectl get pods -A | grep haproxy &>/dev/null; then
        haproxy_ingress="detected"
        log_success "HAProxy Ingress Controller detected"
    fi
    
    # Check existing ingress resources
    local ingress_count=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)
    log_info "Existing ingress resources: $ingress_count"
    
    if [[ $ingress_count -gt 0 ]]; then
        echo -e "\n${CYAN}Existing Ingress Resources:${NC}" | tee -a "$AUDIT_REPORT"
        kubectl get ingress -A -o wide | tee -a "$AUDIT_REPORT"
    fi
    
    update_json "ingress_classes_count" "$ingress_classes"
    update_json "nginx_ingress" "$nginx_ingress"
    update_json "traefik_ingress" "$traefik_ingress"
    update_json "haproxy_ingress" "$haproxy_ingress"
    update_json "existing_ingress_count" "$ingress_count"
}

# Check load balancer setup
check_load_balancer() {
    log_header "Checking Load Balancer Setup"
    
    # Check for LoadBalancer services
    local lb_services=$(kubectl get svc -A --field-selector spec.type=LoadBalancer --no-headers 2>/dev/null | wc -l)
    log_info "LoadBalancer services found: $lb_services"
    
    if [[ $lb_services -gt 0 ]]; then
        echo -e "\n${CYAN}LoadBalancer Services:${NC}" | tee -a "$AUDIT_REPORT"
        kubectl get svc -A --field-selector spec.type=LoadBalancer -o wide | tee -a "$AUDIT_REPORT"
        log_success "LoadBalancer services are configured"
    else
        log_warning "No LoadBalancer services found"
    fi
    
    # Check for MetalLB (common on-prem LB solution)
    if kubectl get pods -A | grep metallb &>/dev/null; then
        log_success "MetalLB detected"
        update_json "metallb_detected" "true"
    else
        log_info "MetalLB not detected"
        update_json "metallb_detected" "false"
    fi
    
    update_json "loadbalancer_services_count" "$lb_services"
}

# Check network CNI
check_network_cni() {
    log_header "Checking Network CNI"
    
    # Check for common CNI plugins
    local calico=""
    local flannel=""
    local cilium=""
    local weave=""
    
    if kubectl get pods -A | grep calico &>/dev/null; then
        calico="detected"
        log_success "Calico CNI detected"
    fi
    
    if kubectl get pods -A | grep flannel &>/dev/null; then
        flannel="detected"
        log_success "Flannel CNI detected"
    fi
    
    if kubectl get pods -A | grep cilium &>/dev/null; then
        cilium="detected"
        log_success "Cilium CNI detected"
    fi
    
    if kubectl get pods -A | grep weave &>/dev/null; then
        weave="detected"
        log_success "Weave CNI detected"
    fi
    
    # Check network policies support
    if kubectl explain networkpolicy &>/dev/null; then
        log_success "NetworkPolicy support available"
        local netpol_count=$(kubectl get networkpolicy -A --no-headers 2>/dev/null | wc -l)
        log_info "Existing NetworkPolicies: $netpol_count"
        update_json "networkpolicy_support" "true"
        update_json "existing_networkpolicies" "$netpol_count"
    else
        log_warning "NetworkPolicy support not available"
        update_json "networkpolicy_support" "false"
    fi
    
    # Check pod CIDR
    local pod_cidr=$(kubectl cluster-info dump | grep -m 1 "cluster-cidr" | sed 's/.*cluster-cidr=\([^"]*\).*/\1/' 2>/dev/null || echo "unknown")
    log_info "Pod CIDR: $pod_cidr"
    
    update_json "calico_cni" "$calico"
    update_json "flannel_cni" "$flannel"
    update_json "cilium_cni" "$cilium"
    update_json "weave_cni" "$weave"
    update_json "pod_cidr" "$pod_cidr"
}

# Check existing monitoring
check_monitoring() {
    log_header "Checking Existing Monitoring Stack"
    
    # Check for Prometheus
    local prometheus=""
    local grafana=""
    local alertmanager=""
    
    if kubectl get pods -A | grep prometheus &>/dev/null; then
        prometheus="detected"
        log_success "Prometheus detected"
        
        # Check for Prometheus operator
        if kubectl get crd | grep prometheus &>/dev/null; then
            log_success "Prometheus Operator CRDs detected"
            update_json "prometheus_operator" "true"
        fi
    else
        log_warning "Prometheus not detected"
        update_json "prometheus_operator" "false"
    fi
    
    if kubectl get pods -A | grep grafana &>/dev/null; then
        grafana="detected"
        log_success "Grafana detected"
    else
        log_warning "Grafana not detected"
    fi
    
    if kubectl get pods -A | grep alertmanager &>/dev/null; then
        alertmanager="detected"
        log_success "AlertManager detected"
    else
        log_warning "AlertManager not detected"
    fi
    
    # Check for monitoring namespaces
    local monitoring_namespaces=""
    for ns in monitoring prometheus-system kube-prometheus-stack; do
        if kubectl get namespace "$ns" &>/dev/null; then
            monitoring_namespaces="$monitoring_namespaces $ns"
            log_info "Monitoring namespace found: $ns"
        fi
    done
    
    # Check for ServiceMonitor CRDs
    if kubectl get crd | grep servicemonitor &>/dev/null; then
        log_success "ServiceMonitor CRDs available"
        update_json "servicemonitor_support" "true"
    else
        log_warning "ServiceMonitor CRDs not found"
        update_json "servicemonitor_support" "false"
    fi
    
    update_json "prometheus" "$prometheus"
    update_json "grafana" "$grafana"
    update_json "alertmanager" "$alertmanager"
    update_json "monitoring_namespaces" "$monitoring_namespaces"
}

# Check security policies
check_security() {
    log_header "Checking Security Policies"
    
    # Check RBAC
    if kubectl auth can-i create clusterroles --as=system:serviceaccount:default:default &>/dev/null; then
        log_warning "Default service account has cluster admin permissions (security risk)"
        update_json "rbac_properly_configured" "false"
    else
        log_success "RBAC appears to be properly configured"
        update_json "rbac_properly_configured" "true"
    fi
    
    # Check Pod Security Policies/Standards
    local psp_count=$(kubectl get psp --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ $psp_count -gt 0 ]]; then
        log_success "Pod Security Policies found: $psp_count"
        update_json "pod_security_policies" "$psp_count"
    else
        log_warning "No Pod Security Policies found"
        update_json "pod_security_policies" "0"
    fi
    
    # Check for security-related CRDs
    local security_crds=""
    for crd in securitycontextconstraints podsecuritypolicies networkpolicies; do
        if kubectl get crd | grep $crd &>/dev/null; then
            security_crds="$security_crds $crd"
        fi
    done
    
    if [[ -n "$security_crds" ]]; then
        log_success "Security-related CRDs found:$security_crds"
    else
        log_warning "No security-related CRDs found"
    fi
    
    # Check for security tools
    local falco=""
    local opa_gatekeeper=""
    
    if kubectl get pods -A | grep falco &>/dev/null; then
        falco="detected"
        log_success "Falco security runtime detected"
    fi
    
    if kubectl get pods -A | grep gatekeeper &>/dev/null; then
        opa_gatekeeper="detected"
        log_success "OPA Gatekeeper detected"
    fi
    
    update_json "security_crds" "$security_crds"
    update_json "falco" "$falco"
    update_json "opa_gatekeeper" "$opa_gatekeeper"
}

# Check backup strategy
check_backup() {
    log_header "Checking Backup Strategy"
    
    # Check for Velero
    local velero=""
    if kubectl get pods -A | grep velero &>/dev/null; then
        velero="detected"
        log_success "Velero backup solution detected"
        
        # Check Velero backups
        if kubectl get backups -A &>/dev/null; then
            local backup_count=$(kubectl get backups -A --no-headers 2>/dev/null | wc -l)
            log_info "Velero backups found: $backup_count"
            update_json "velero_backups_count" "$backup_count"
        fi
    else
        log_warning "Velero not detected"
    fi
    
    # Check for other backup solutions
    local backup_solutions=""
    for solution in kasten longhorn stash; do
        if kubectl get pods -A | grep $solution &>/dev/null; then
            backup_solutions="$backup_solutions $solution"
            log_success "$solution backup solution detected"
        fi
    done
    
    # Check persistent volumes
    local pv_count=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
    log_info "Persistent volumes: $pv_count"
    
    if [[ $pv_count -gt 0 ]]; then
        echo -e "\n${CYAN}Persistent Volumes:${NC}" | tee -a "$AUDIT_REPORT"
        kubectl get pv | tee -a "$AUDIT_REPORT"
    fi
    
    update_json "velero" "$velero"
    update_json "backup_solutions" "$backup_solutions"
    update_json "persistent_volumes_count" "$pv_count"
}

# Check external access
check_external_access() {
    log_header "Checking External Access Setup"
    
    # Check for external IPs
    local external_ips=$(kubectl get svc -A -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | wc -l)
    log_info "Services with external IPs: $external_ips"
    
    # Check NodePort services
    local nodeport_services=$(kubectl get svc -A --field-selector spec.type=NodePort --no-headers 2>/dev/null | wc -l)
    log_info "NodePort services: $nodeport_services"
    
    if [[ $nodeport_services -gt 0 ]]; then
        echo -e "\n${CYAN}NodePort Services:${NC}" | tee -a "$AUDIT_REPORT"
        kubectl get svc -A --field-selector spec.type=NodePort | tee -a "$AUDIT_REPORT"
    fi
    
    # Check for cert-manager
    local cert_manager=""
    if kubectl get pods -A | grep cert-manager &>/dev/null; then
        cert_manager="detected"
        log_success "cert-manager detected"
        
        # Check certificates
        if kubectl get certificates -A &>/dev/null; then
            local cert_count=$(kubectl get certificates -A --no-headers 2>/dev/null | wc -l)
            log_info "Certificates managed by cert-manager: $cert_count"
            update_json "cert_manager_certificates" "$cert_count"
        fi
    else
        log_warning "cert-manager not detected"
    fi
    
    update_json "external_ips_count" "$external_ips"
    update_json "nodeport_services_count" "$nodeport_services"
    update_json "cert_manager" "$cert_manager"
}

# Check cluster addons and operators
check_addons() {
    log_header "Checking Cluster Addons and Operators"
    
    # Check for common operators
    local operators=""
    
    for operator in "operator" "controller"; do
        local count=$(kubectl get pods -A | grep -i $operator | wc -l)
        if [[ $count -gt 0 ]]; then
            log_info "Pods with '$operator' in name: $count"
        fi
    done
    
    # Check for Helm
    if command -v helm &> /dev/null; then
        local helm_releases=$(helm list -A --no-headers 2>/dev/null | wc -l || echo "0")
        log_info "Helm releases found: $helm_releases"
        update_json "helm_releases_count" "$helm_releases"
        
        if [[ $helm_releases -gt 0 ]]; then
            echo -e "\n${CYAN}Helm Releases:${NC}" | tee -a "$AUDIT_REPORT"
            helm list -A | tee -a "$AUDIT_REPORT"
        fi
    else
        log_warning "Helm CLI not available"
        update_json "helm_available" "false"
    fi
    
    # Check CRDs
    local crd_count=$(kubectl get crd --no-headers 2>/dev/null | wc -l)
    log_info "Custom Resource Definitions: $crd_count"
    update_json "crd_count" "$crd_count"
    
    if [[ $crd_count -gt 0 ]]; then
        echo -e "\n${CYAN}Custom Resource Definitions:${NC}" | tee -a "$AUDIT_REPORT"
        kubectl get crd | head -20 | tee -a "$AUDIT_REPORT"
        if [[ $crd_count -gt 20 ]]; then
            echo "... and $((crd_count - 20)) more" | tee -a "$AUDIT_REPORT"
        fi
    fi
}

# Generate recommendations
generate_recommendations() {
    log_header "Recommendations for Microservices Migration"
    
    echo -e "\n${CYAN}🎯 Microservices Readiness Assessment:${NC}" | tee -a "$AUDIT_REPORT"
    
    # Storage recommendations
    local storage_classes=$(jq -r '.cluster_audit.storage_classes_count' "$JSON_REPORT")
    if [[ "$storage_classes" == "0" ]]; then
        echo "❗ CRITICAL: Configure storage classes before deploying stateful services" | tee -a "$AUDIT_REPORT"
    else
        echo "✅ Storage: Ready for persistent workloads" | tee -a "$AUDIT_REPORT"
    fi
    
    # Ingress recommendations
    local ingress_classes=$(jq -r '.cluster_audit.ingress_classes_count' "$JSON_REPORT")
    if [[ "$ingress_classes" == "0" ]]; then
        echo "❗ CRITICAL: Install ingress controller (recommend NGINX Ingress)" | tee -a "$AUDIT_REPORT"
    else
        echo "✅ Ingress: Ready for external traffic routing" | tee -a "$AUDIT_REPORT"
    fi
    
    # Monitoring recommendations
    local prometheus=$(jq -r '.cluster_audit.prometheus' "$JSON_REPORT")
    if [[ "$prometheus" != "detected" ]]; then
        echo "⚠️  RECOMMENDED: Install Prometheus + Grafana for monitoring" | tee -a "$AUDIT_REPORT"
    else
        echo "✅ Monitoring: Prometheus stack detected" | tee -a "$AUDIT_REPORT"
    fi
    
    # Security recommendations
    local rbac=$(jq -r '.cluster_audit.rbac_properly_configured' "$JSON_REPORT")
    if [[ "$rbac" == "false" ]]; then
        echo "❗ CRITICAL: Review and tighten RBAC permissions" | tee -a "$AUDIT_REPORT"
    else
        echo "✅ Security: RBAC properly configured" | tee -a "$AUDIT_REPORT"
    fi
    
    # Network policy recommendations
    local netpol_support=$(jq -r '.cluster_audit.networkpolicy_support' "$JSON_REPORT")
    if [[ "$netpol_support" == "true" ]]; then
        echo "✅ Network: NetworkPolicy support available for micro-segmentation" | tee -a "$AUDIT_REPORT"
    else
        echo "⚠️  RECOMMENDED: CNI with NetworkPolicy support for better security" | tee -a "$AUDIT_REPORT"
    fi
    
    # Backup recommendations
    local velero=$(jq -r '.cluster_audit.velero' "$JSON_REPORT")
    if [[ "$velero" != "detected" ]]; then
        echo "⚠️  RECOMMENDED: Install Velero for cluster backup/disaster recovery" | tee -a "$AUDIT_REPORT"
    else
        echo "✅ Backup: Velero detected for disaster recovery" | tee -a "$AUDIT_REPORT"
    fi
    
    echo -e "\n${CYAN}🚀 Next Steps for Microservices Implementation:${NC}" | tee -a "$AUDIT_REPORT"
    echo "1. Install ArgoCD for GitOps deployment" | tee -a "$AUDIT_REPORT"
    echo "2. Install Istio service mesh for microservices communication" | tee -a "$AUDIT_REPORT"
    echo "3. Setup HashiCorp Vault or External Secrets for secret management" | tee -a "$AUDIT_REPORT"
    echo "4. Configure namespace isolation and resource quotas" | tee -a "$AUDIT_REPORT"
    echo "5. Implement network policies for micro-segmentation" | tee -a "$AUDIT_REPORT"
}

# Main execution
main() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║              Kubernetes Cluster Audit Script                 ║
║          Microservices Migration Readiness Check             ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_info "Starting comprehensive Kubernetes cluster audit..."
    log_info "Audit report will be saved to: $AUDIT_REPORT"
    log_info "JSON report will be saved to: $JSON_REPORT"
    
    # Run all checks
    check_kubectl
    check_k8s_version
    check_nodes_resources
    check_storage
    check_ingress
    check_load_balancer
    check_network_cni
    check_monitoring
    check_security
    check_backup
    check_external_access
    check_addons
    generate_recommendations
    
    # Final summary
    log_header "Audit Summary"
    log_success "Cluster audit completed successfully!"
    log_info "Text report: $AUDIT_REPORT"
    log_info "JSON report: $JSON_REPORT"
    
    echo -e "\n${CYAN}Quick Access Commands:${NC}"
    echo "View report: cat $AUDIT_REPORT"
    echo "JSON query example: jq '.cluster_audit.server_version' $JSON_REPORT"
    echo "Upload to remote: scp $AUDIT_REPORT user@server:/path/"
}

# Trap for cleanup
trap 'echo "Audit interrupted"; exit 1' INT TERM

# Run main function
main "$@"