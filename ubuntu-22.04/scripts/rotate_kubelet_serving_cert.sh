#!/bin/bash
#
# rotate_kubelet_serving_cert.sh
# Backs up and rotates the kubelet serving certificate on a remote node,
# then approves the new CSR and waits for the node to become Ready again.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME --node <node-name> [--ssh-host <host>] [--ssh-user <user>] [--ssh-key <path>] [--timeout <seconds>]

Options:
  --node        Name of the Kubernetes node (also used as SSH host if --ssh-host is omitted)
  --ssh-host    SSH hostname or IP (defaults to node name)
  --ssh-user    SSH user (default: ansible)
  --ssh-key     Path to SSH private key (optional, defaults to SSH configuration)
  --timeout     Seconds to wait for CSR issuance and node to become Ready (default: 180)
  -h, --help    Show this help message

Example:
  $SCRIPT_NAME --node k8s-worker-2 --ssh-host 192.168.0.191
EOF
}

NODE_NAME=""
SSH_HOST=""
SSH_USER="ansible"
SSH_KEY=""
TIMEOUT_SECONDS=180

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node)
            NODE_NAME="$2"
            shift 2
            ;;
        --ssh-host)
            SSH_HOST="$2"
            shift 2
            ;;
        --ssh-user)
            SSH_USER="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$NODE_NAME" ]]; then
    log_error "Missing required --node argument"
    usage
    exit 1
fi

for bin in kubectl ssh jq; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        log_error "Required command '$bin' not found."
        exit 1
    fi
done

SSH_TARGET="${SSH_HOST:-$NODE_NAME}"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new)
if [[ -n "$SSH_KEY" ]]; then
    SSH_OPTS+=(-i "$SSH_KEY")
fi

remote_exec() {
    # shellcheck disable=SC2029
    ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SSH_TARGET}" "$@"
}

log_info "Validating node ${NODE_NAME} is reachable via kubectl"
kubectl get "node/${NODE_NAME}" >/dev/null

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
PKI_DIR="/var/lib/kubelet/pki"

log_info "Creating backup of existing kubelet serving certs on ${SSH_TARGET}"
remote_exec sudo bash <<EOF
set -euo pipefail
PKI_DIR="${PKI_DIR}"
BACKUP_DIR="\${PKI_DIR}/backup-${TIMESTAMP}"
mkdir -p "\${BACKUP_DIR}"
for item in kubelet.crt kubelet.key kubelet-server-current.pem kubelet-server-*.pem; do
    if compgen -G "\${PKI_DIR}/\${item}" > /dev/null; then
        cp -p \${PKI_DIR}/\${item} "\${BACKUP_DIR}/" || true
    fi
done
EOF

log_info "Removing existing kubelet serving certificates on ${SSH_TARGET}"
remote_exec sudo bash <<'EOF'
set -euo pipefail
PKI_DIR="/var/lib/kubelet/pki"
rm -f \
    "${PKI_DIR}/kubelet.crt" \
    "${PKI_DIR}/kubelet.key" \
    "${PKI_DIR}/kubelet-server-current.pem"
shopt -s nullglob
for pem in "${PKI_DIR}"/kubelet-server-*.pem; do
    rm -f "$pem"
done
EOF

log_info "Restarting kubelet on ${SSH_TARGET}"
remote_exec sudo systemctl restart kubelet

log_info "Waiting for new kubelet serving CSR from node ${NODE_NAME}"
CSR_NAME=""
DEADLINE=$((SECONDS + TIMEOUT_SECONDS))
while [[ $SECONDS -lt $DEADLINE ]]; do
    CSR_NAME="$(kubectl get csr -o json | jq -r --arg node "$NODE_NAME" '
        .items[]
        | select(.spec.username == ("system:node:" + $node))
        | select(.spec.signerName == "kubernetes.io/kubelet-serving")
        | select(.status.conditions == null)
        | .metadata.name
    ' | tail -n 1)"

    if [[ -n "$CSR_NAME" ]]; then
        break
    fi

    sleep 3
done

if [[ -z "$CSR_NAME" ]]; then
    log_error "Timed out waiting for kubelet-serving CSR from ${NODE_NAME}"
    exit 1
fi

log_info "Approving CSR ${CSR_NAME}"
kubectl certificate approve "${CSR_NAME}" >/dev/null

log_info "Waiting for node ${NODE_NAME} to become Ready"
if ! kubectl wait --for=condition=Ready "node/${NODE_NAME}" --timeout="${TIMEOUT_SECONDS}s" >/dev/null; then
    log_warn "Node ${NODE_NAME} did not report Ready within ${TIMEOUT_SECONDS}s – check manually."
    exit 1
fi

log_info "Verifying new serving certificate SANs on ${SSH_TARGET}"
if remote_exec sudo test -f "${PKI_DIR}/kubelet-server-current.pem"; then
    remote_exec sudo openssl x509 -in "${PKI_DIR}/kubelet-server-current.pem" -noout -text \
        | grep -A1 "Subject Alternative Name" || log_warn "Could not read SANs from kubelet-server-current.pem"
else
    log_warn "kubelet-server-current.pem not found after rotation – verify manually."
fi

log_info "Kubelet serving certificate rotation for ${NODE_NAME} completed successfully."
