#!/bin/bash

set -e

echo "========================================="
echo "Export ArgoCD CA Certificate"
echo "========================================="
echo ""

OUTPUT_FILE="${1:-devops-lab-ca.crt}"

# Get CA certificate
echo "Extracting CA certificate from Kubernetes..."
kubectl get secret -n cert-manager selfsigned-ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d > "$OUTPUT_FILE"

echo ""
echo "✅ CA certificate exported to: $OUTPUT_FILE"
echo ""
echo "Transfer this file to your device and install:"
echo ""
echo "Windows:"
echo "  1. Double-click the .crt file"
echo "  2. Install to 'Trusted Root Certification Authorities'"
echo ""
echo "macOS:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $OUTPUT_FILE"
echo ""
echo "Linux (Ubuntu/Debian):"
echo "  sudo cp $OUTPUT_FILE /usr/local/share/ca-certificates/"
echo "  sudo update-ca-certificates"
echo ""
echo "Linux (RHEL/Oracle/CentOS):"
echo "  sudo cp $OUTPUT_FILE /etc/pki/ca-trust/source/anchors/"
echo "  sudo update-ca-trust extract"
echo ""
echo "Android:"
echo "  Settings → Security → Install a certificate → CA certificate"
echo ""
echo "iOS:"
echo "  Send via email/AirDrop → Install → Trust in Settings"
echo ""
