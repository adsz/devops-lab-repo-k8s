#!/bin/bash

# Velero Installation Script for Enterprise Kubernetes Backup
# Deploys Velero operator with AWS S3 backend integration

set -euo pipefail

# Configuration variables
VELERO_VERSION="v1.12.1"
VELERO_NAMESPACE="velero"
S3_BUCKET="aws5-k8s-backup"
AWS_REGION="eu-central-1"
BACKUP_LOCATION="default"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Credentials live in cloud-credentials.conf (gitignored) with lines:
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...
CREDENTIALS_OVERRIDE="${1:-${VELERO_CREDENTIALS_FILE:-}}"
DEFAULT_CREDENTIALS_REPO="${SCRIPT_DIR}/cloud-credentials.conf"
DEFAULT_CREDENTIALS_HOME="${HOME}/.config/k8s-local/velero/cloud-credentials.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install Helm first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    log_info "Creating Velero namespace..."
    
    kubectl create namespace ${VELERO_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespace ${VELERO_NAMESPACE} created/updated"
}

# Install Velero CLI if not present
install_velero_cli() {
    if command -v velero &> /dev/null; then
        log_info "Velero CLI already installed: $(velero version --client-only)"
        return 0
    fi
    
    log_info "Installing Velero CLI ${VELERO_VERSION}..."
    
    # Download and install Velero CLI
    VELERO_TARBALL="velero-${VELERO_VERSION}-linux-amd64.tar.gz"
    
    curl -L -o /tmp/${VELERO_TARBALL} \
        "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/${VELERO_TARBALL}"
    
    tar -xzf /tmp/${VELERO_TARBALL} -C /tmp/
    sudo mv /tmp/velero-${VELERO_VERSION}-linux-amd64/velero /usr/local/bin/
    
    # Cleanup
    rm -rf /tmp/velero-${VELERO_VERSION}-linux-amd64 /tmp/${VELERO_TARBALL}
    
    log_success "Velero CLI installed successfully"
}

# Create AWS credentials secret (using IAM roles - placeholder for manual setup)
ensure_credentials_sources() {
    log_info "Checking for Velero cloud credentials..."

    if kubectl get secret cloud-credentials --namespace="${VELERO_NAMESPACE}" >/dev/null 2>&1; then
        log_success "Found existing cloud-credentials secret in cluster"
        return 0
    fi

    local creds_file=""
    if [[ -n "${CREDENTIALS_OVERRIDE}" ]]; then
        creds_file="${CREDENTIALS_OVERRIDE}"
    elif [[ -f "${DEFAULT_CREDENTIALS_REPO}" ]]; then
        creds_file="${DEFAULT_CREDENTIALS_REPO}"
    elif [[ -f "${DEFAULT_CREDENTIALS_HOME}" ]]; then
        creds_file="${DEFAULT_CREDENTIALS_HOME}"
    fi

    local access_key secret_key

    if [[ -n "${creds_file}" ]]; then
        if [[ ! -f "${creds_file}" ]]; then
            log_error "Credentials file not found: ${creds_file}"
            exit 1
        fi
        log_info "Loading credentials from ${creds_file}"
        # shellcheck disable=SC1090
        source "${creds_file}"
        access_key="${AWS_ACCESS_KEY_ID:-}"
        secret_key="${AWS_SECRET_ACCESS_KEY:-}"
    else
        log_info "No credentials file provided; falling back to environment variables"
        access_key="${AWS_ACCESS_KEY_ID:-}"
        secret_key="${AWS_SECRET_ACCESS_KEY:-}"
    fi

    if [[ -z "${access_key}" || -z "${secret_key}" ]]; then
        log_error "No credentials detected. Provide AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY via file or environment."
        log_info "Accepted options:"
        log_info "- ./install.sh /path/to/cloud-credentials.conf"
        log_info "- VELERO_CREDENTIALS_FILE=/path/to/cloud-credentials.conf ./install.sh"
        log_info "- Place file at ${DEFAULT_CREDENTIALS_REPO} or ${DEFAULT_CREDENTIALS_HOME}"
        log_info "- Export AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY and run ./install.sh"
        exit 1
    fi

    kubectl create secret generic cloud-credentials \
        --namespace="${VELERO_NAMESPACE}" \
        --from-literal=cloud=$'[default]\naws_access_key_id='"${access_key}"$'\naws_secret_access_key='"${secret_key}" \
        --dry-run=client -o yaml | kubectl apply -f -

    log_success "cloud-credentials secret applied"
}

# Install Velero using Helm
install_velero_helm() {
    log_info "Installing Velero using Helm..."
    
    # Add VMware Tanzu Helm repository
    helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
    helm repo update
    
    # Install Velero with custom values (use latest chart version)
    helm upgrade --install \
        velero \
        vmware-tanzu/velero \
        --namespace="${VELERO_NAMESPACE}" \
        --values "${SCRIPT_DIR}/values.yaml" \
        --wait \
        --timeout=10m
    
    log_success "Velero installed via Helm"
}

# Configure backup storage location
configure_backup_location() {
    log_info "Configuring backup storage location..."
    
    # Apply backup storage location configuration
    kubectl apply -f "${SCRIPT_DIR}/backup-storage-location.yaml"
    
    log_success "Backup storage location configured"
}

# Configure volume snapshot location
configure_snapshot_location() {
    log_info "Configuring volume snapshot location..."
    
    # Apply volume snapshot location configuration
    kubectl apply -f "${SCRIPT_DIR}/volume-snapshot-location.yaml"
    
    log_success "Volume snapshot location configured"
}

# Verify installation
verify_installation() {
    log_info "Verifying Velero installation..."
    
    # Wait for Velero deployment to be ready
    kubectl wait --namespace=${VELERO_NAMESPACE} \
        --for=condition=available \
        --timeout=300s \
        deployment/velero
    
    # Check Velero status
    if velero version 2>/dev/null; then
        log_success "Velero installation verified successfully"
    else
        log_error "Velero installation verification failed"
        return 1
    fi
    
    # Check backup location status
    log_info "Checking backup location status..."
    velero backup-location get
}

# Create initial backup schedule
create_backup_schedule() {
    log_info "Creating daily backup schedule..."
    
    # Apply backup schedule configuration
    kubectl apply -f "${SCRIPT_DIR}/backup-schedule.yaml"
    
    log_success "Daily backup schedule created"
}

# Main execution
main() {
    log_info "Starting Velero installation for enterprise Kubernetes backup..."
    
    check_prerequisites
    create_namespace
    install_velero_cli
    ensure_credentials_sources
    install_velero_helm
    configure_backup_location
    configure_snapshot_location
    verify_installation
    create_backup_schedule
    
    log_success "Velero installation completed successfully!"
    log_info "Next steps:"
    log_info "1. Configure IAM roles for service accounts (IRSA) for production"
    log_info "2. Update cloud-credentials secret with proper AWS access"
    log_info "3. Test backup and restore functionality"
    log_info "4. Configure monitoring and alerting for backup jobs"
}

# Run main function
main "$@"
