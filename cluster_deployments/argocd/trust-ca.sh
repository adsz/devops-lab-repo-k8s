#!/bin/bash

set -e

echo "========================================="
echo "ArgoCD - Install CA Certificate"
echo "========================================="
echo ""
echo "This will install the ArgoCD CA certificate to your system trust store."
echo "After this, https://192.168.0.215 will show as SECURE in your browser."
echo ""

# Get CA certificate
echo "Extracting CA certificate from Kubernetes..."
kubectl get secret -n cert-manager selfsigned-ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/devops-lab-ca.crt

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Detected: Linux"
    echo "Installing CA certificate to system trust store..."

    # Check if RHEL/CentOS/Oracle Linux or Debian/Ubuntu
    if command -v update-ca-trust &> /dev/null; then
        # RHEL-based (Oracle Linux, CentOS, Fedora)
        sudo cp /tmp/devops-lab-ca.crt /etc/pki/ca-trust/source/anchors/devops-lab-ca.crt
        sudo update-ca-trust extract
        CA_PATH="/etc/pki/ca-trust/source/anchors/devops-lab-ca.crt"
    elif command -v update-ca-certificates &> /dev/null; then
        # Debian-based (Ubuntu, Debian)
        sudo cp /tmp/devops-lab-ca.crt /usr/local/share/ca-certificates/devops-lab-ca.crt
        sudo update-ca-certificates
        CA_PATH="/usr/local/share/ca-certificates/devops-lab-ca.crt"
    else
        echo "ERROR: Cannot detect certificate management tool"
        exit 1
    fi

    echo ""
    echo "✅ CA certificate installed successfully!"
    echo ""
    echo "For Firefox, you need to manually import the certificate:"
    echo "1. Open Firefox Settings"
    echo "2. Go to Privacy & Security → Certificates → View Certificates"
    echo "3. Click 'Authorities' tab → Import"
    echo "4. Select: ${CA_PATH}"
    echo "5. Check 'Trust this CA to identify websites'"

elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected: macOS"
    echo "Installing CA certificate to system keychain..."

    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/devops-lab-ca.crt

    echo ""
    echo "✅ CA certificate installed successfully!"

else
    echo "Unsupported OS: $OSTYPE"
    echo ""
    echo "CA certificate saved to: /tmp/devops-lab-ca.crt"
    echo ""
    echo "On Windows:"
    echo "1. Copy /tmp/devops-lab-ca.crt to Windows machine"
    echo "2. Double-click the .crt file"
    echo "3. Click 'Install Certificate'"
    echo "4. Select 'Local Machine'"
    echo "5. Place in 'Trusted Root Certification Authorities'"
    exit 1
fi

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Now access: https://192.168.0.215"
echo "Browser will show: 🔒 Secure"
echo ""
