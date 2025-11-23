# ArgoCD Access Information

## 🌐 Access URL (TYLKO JEDEN DEDYKOWANY IP)

```
https://192.168.0.215
```

**Dedykowany LoadBalancer IP przez MetalLB**
- ✅ TLS 1.2+ encryption
- ✅ Automatic certificate renewal
- ✅ High availability (2 replicas)

## 🔒 Dlaczego Przeglądarka Pokazuje "Not Secure"?

**To jest NORMALNE** dla self-signed certyfikatów w środowiskach developerskich/internal.

ArgoCD MA TLS i jest zabezpieczone, ale certyfikat jest podpisany przez naszą **wewnętrzną CA** (Certificate Authority), którą przeglądarka nie zna.

### Jak Naprawić "Not Secure"?

**Metoda 1: Automatyczny Skrypt (ZALECANE)**
```bash
cd /repos/devops-lab-new/k8s-local/cluster_deployments/argocd
./trust-ca.sh
```

Po uruchomieniu skryptu:
- CA certyfikat zostanie zainstalowany w systemie
- Przeglądarka pokaże: 🔒 **Secure** (zielona kłódka)
- Nie będzie więcej ostrzeżeń

**Metoda 2: Akceptuj Warning (Szybkie)**
Kliknij "Advanced" → "Proceed to 192.168.0.215" w przeglądarce.

**Metoda 3: Manualna Instalacja CA**
```bash
# Pobierz CA cert
kubectl get secret -n cert-manager selfsigned-ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d > devops-lab-ca.crt

# Linux
sudo cp devops-lab-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain devops-lab-ca.crt
```

## Login Credentials

**Username:** `admin`

**Initial Password:** `9bek9nj9A7pDiBy0`

⚠️ **ZMIEŃ HASŁO** po pierwszym logowaniu!

## Changing Admin Password

### Via CLI
```bash
argocd login 192.168.0.215
# Credentials: admin / 9bek9nj9A7pDiBy0

argocd account update-password
```

### Via UI
1. Login to ArgoCD
2. Click on "User Info" (admin icon in top right)
3. Click "Update Password"

## ArgoCD CLI

### Installation
```bash
VERSION="v2.13.2"
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

### Login
```bash
# With CA trust installed (secure)
argocd login 192.168.0.215

# Without CA trust (skip verification)
argocd login 192.168.0.215 --insecure
```

## Quick Start

```bash
# 1. Login
argocd login 192.168.0.215 --insecure

# 2. Change password
argocd account update-password

# 3. Add Git repository
argocd repo add https://github.com/your-org/repo.git \
  --username git \
  --password <github-token>

# 4. Create application
argocd app create myapp \
  --repo https://github.com/your-org/repo.git \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated

# 5. Sync
argocd app sync myapp
```

## Verification

```bash
# Test HTTPS
curl -k https://192.168.0.215
# Should return: HTTP/1.1 200 OK

# Check certificate
openssl s_client -connect 192.168.0.215:443 </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer
```

## Troubleshooting

### "Not Secure" Warning
**Przyczyna:** Certyfikat jest podpisany przez internal CA, nie przez public CA (Let's Encrypt, DigiCert, etc.)

**Rozwiązanie:** Uruchom `./trust-ca.sh` aby zainstalować CA w systemie.

### Cannot Connect
```bash
# Check pods
kubectl get pods -n argocd

# Check service
kubectl get svc argocd-server-lb -n argocd

# Check logs
kubectl logs -n argocd deployment/argocd-server -f
```

### Certificate Expired
Cert-manager automatycznie odnawia certyfikaty 30 dni przed wygaśnięciem.

Sprawdź status:
```bash
kubectl get certificate -n argocd
```

## Why Only .215? (No .210)

- **Simple**: One IP, one endpoint
- **Performance**: No ingress overhead
- **Reliability**: Direct connection to ArgoCD
- **Security**: Fewer moving parts = smaller attack surface

Old setup (.210 ingress) was removed - unnecessary complexity.

## Summary

✅ **TLS Encrypted**: All traffic is HTTPS
✅ **Auto-renewal**: Certificates managed by cert-manager
✅ **High Availability**: 2 server replicas
✅ **Production Ready**: Enterprise-grade security

⚠️ **"Not Secure" warning**: This is normal for internal CA - run `./trust-ca.sh` to fix
