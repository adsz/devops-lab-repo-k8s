# Kubernetes Diagnostic Deployments - "Złota 22"

Kompletny zestaw 22 obrazów Docker do testowania, diagnostyki i administracji klastra Kubernetes.

## 📋 Spis obrazów

### Web/HTTP Testing (8 obrazów) - **Kustomize**
- nginx:alpine
- httpd:alpine
- traefik/whoami
- gcr.io/google-samples/hello-app:1.0
- kennethreitz/httpbin
- ealen/echo-server
- k8s.gcr.io/echoserver
- gcr.io/kuar-demo/kuard-amd64:blue

### Network/Debug (5 obrazów) - **Plain YAML**
- busybox
- curlimages/curl
- nicolaka/netshoot
- praqma/network-multitool
- alpine

### DNS Debugging (1 obraz) - **Plain YAML**
- tutum/dnsutils

### Databases (3 obrazy) - **Helm**
- redis:7-alpine
- postgres:16-alpine
- mariadb:11-alpine

### Storage (1 obraz) - **Helm**
- minio/minio

### Registry (1 obraz) - **Helm**
- registry:2

### Service Mesh (1 obraz) - **Plain YAML**
- envoyproxy/envoy:distroless-v1.31

### eBPF (1 obraz) - **Plain YAML**
- iovisor/bpftrace

### K8s Core (1 obraz) - **Plain YAML**
- k8s.gcr.io/pause:3.9

---

## 🚀 Quick Start

### Wymagania wstępne
```bash
# Sprawdź połączenie z klastrem
kubectl cluster-info
kubectl get nodes

# Zainstaluj narzędzia (jeśli brak)
# Kustomize (zwykle wbudowany w kubectl >= 1.14)
kubectl version --client

# Helm 3
helm version
```

### Tworzenie namespace'ów
```bash
# Stwórz wszystkie wymagane namespace'y
kubectl create namespace diagnostic-web
kubectl create namespace diagnostic-web-dev
kubectl create namespace diagnostic-web-prod
kubectl create namespace diagnostic-net
kubectl create namespace diagnostic-db
kubectl create namespace diagnostic-storage
kubectl create namespace diagnostic-registry
kubectl create namespace diagnostic-mesh
kubectl create namespace diagnostic-ebpf
kubectl create namespace diagnostic-core
```

---

## 📦 Deployment - Szczegółowe instrukcje

## 1️⃣ Web/HTTP Testing - Kustomize (8 obrazów)

### Struktura
```
web-http/
├── base/                    # Bazowe manifesty
│   ├── kustomization.yaml
│   ├── nginx-deployment.yaml
│   ├── httpd-deployment.yaml
│   ├── whoami-deployment.yaml
│   ├── hello-app-deployment.yaml
│   ├── httpbin-deployment.yaml
│   ├── echo-server-deployment.yaml
│   ├── echoserver-deployment.yaml
│   └── kuard-deployment.yaml
└── overlays/
    ├── dev/                 # Środowisko dev
    │   ├── kustomization.yaml
    │   └── replica-patch.yaml
    └── prod/                # Środowisko prod
        ├── kustomization.yaml
        └── replica-patch.yaml
```

### Deployment

**Base (namespace: diagnostic-web):**
```bash
cd web-http
kubectl apply -k base/
```

**Dev environment (namespace: diagnostic-web-dev):**
```bash
kubectl apply -k overlays/dev/
```

**Prod environment (namespace: diagnostic-web-prod, więcej replik):**
```bash
kubectl apply -k overlays/prod/
```

### Weryfikacja
```bash
# Base
kubectl get pods,svc -n diagnostic-web

# Dev
kubectl get pods,svc -n diagnostic-web-dev

# Prod
kubectl get pods,svc -n diagnostic-web-prod

# Test nginx
kubectl run test-curl --rm -it --image=curlimages/curl -- curl http://nginx.diagnostic-web
```

### Usuwanie
```bash
kubectl delete -k base/
kubectl delete -k overlays/dev/
kubectl delete -k overlays/prod/
```

---

## 2️⃣ Network Debug Tools - Plain YAML (5 obrazów)

### Deployment
```bash
cd network-debug

# Deploy wszystkich narzędzi naraz
kubectl apply -f busybox.yaml
kubectl apply -f curl.yaml
kubectl apply -f netshoot.yaml
kubectl apply -f network-multitool.yaml
kubectl apply -f alpine.yaml

# Lub wszystko naraz
kubectl apply -f .
```

### Weryfikacja
```bash
kubectl get pods -n diagnostic-net

# Test busybox
kubectl exec -it busybox -n diagnostic-net -- ping -c 3 google.com

# Test curl
kubectl exec -it curl -n diagnostic-net -- curl -I https://google.com

# Test netshoot (zaawansowane narzędzia)
kubectl exec -it netshoot -n diagnostic-net -- bash
# W środku: nmap, tcpdump, iperf3, mtr, etc.

# Test network-multitool (HTTP server + tools)
kubectl exec -it network-multitool -n diagnostic-net -- bash
curl http://network-multitool.diagnostic-net:8080

# Test alpine
kubectl exec -it alpine -n diagnostic-net -- sh
```

### Przykładowe zastosowania
```bash
# Diagnostyka DNS
kubectl exec -it netshoot -n diagnostic-net -- nslookup kubernetes.default

# Test połączenia do serwisu
kubectl exec -it curl -n diagnostic-net -- curl http://nginx.diagnostic-web

# Skanowanie portów
kubectl exec -it netshoot -n diagnostic-net -- nmap -p 80,443 nginx.diagnostic-web

# Analiza ruchu sieciowego (wymaga uprawnień)
kubectl exec -it netshoot -n diagnostic-net -- tcpdump -i any port 80 -n
```

### Usuwanie
```bash
kubectl delete -f network-debug/
```

---

## 3️⃣ DNS Debugging - Plain YAML (1 obraz)

### Deployment
```bash
cd dns
kubectl apply -f dnsutils.yaml
```

### Weryfikacja i użycie
```bash
kubectl get pod dnsutils -n diagnostic-net

# Test DNS
kubectl exec -it dnsutils -n diagnostic-net -- nslookup kubernetes.default
kubectl exec -it dnsutils -n diagnostic-net -- dig @8.8.8.8 google.com
kubectl exec -it dnsutils -n diagnostic-net -- host kubernetes.default

# Test DNS wewnętrznego K8s
kubectl exec -it dnsutils -n diagnostic-net -- nslookup nginx.diagnostic-web.svc.cluster.local
```

### Usuwanie
```bash
kubectl delete -f dns/dnsutils.yaml
```

---

## 4️⃣ Databases - Helm (3 obrazy)

### Deployment Redis

```bash
cd databases/redis

# Deploy z domyślnymi wartościami
helm install redis-diag . -n diagnostic-db --create-namespace

# Deploy z custom values
helm install redis-diag . -n diagnostic-db \
  --set redis.password="mysecret" \
  --set persistence.enabled=true \
  --set persistence.size=5Gi

# Upgrade
helm upgrade redis-diag . -n diagnostic-db

# List
helm list -n diagnostic-db
```

### Weryfikacja Redis
```bash
kubectl get pods,svc -n diagnostic-db

# Test połączenia
kubectl run redis-client --rm -it --image=redis:7-alpine -n diagnostic-db -- bash
redis-cli -h redis-diag-redis-diagnostic
ping
set testkey "Hello Redis"
get testkey
exit
```

### Deployment PostgreSQL

```bash
cd databases/postgres

# Deploy
helm install postgres-diag . -n diagnostic-db --create-namespace

# Deploy z custom values
helm install postgres-diag . -n diagnostic-db \
  --set postgres.password="mypassword" \
  --set postgres.database="mydb" \
  --set persistence.enabled=true
```

### Weryfikacja PostgreSQL
```bash
kubectl get pods,svc -n diagnostic-db

# Test połączenia
kubectl run psql-client --rm -it --image=postgres:16-alpine -n diagnostic-db -- bash
psql -h postgres-diag-postgres-diagnostic -U postgres -d testdb
\dt
CREATE TABLE test (id serial PRIMARY KEY, name VARCHAR(50));
\q
```

### Deployment MariaDB

```bash
cd databases/mariadb

# Deploy
helm install mariadb-diag . -n diagnostic-db --create-namespace

# Deploy z custom values
helm install mariadb-diag . -n diagnostic-db \
  --set mariadb.rootPassword="rootpass" \
  --set mariadb.database="mydb" \
  --set persistence.enabled=true
```

### Weryfikacja MariaDB
```bash
kubectl get pods,svc -n diagnostic-db

# Test połączenia
kubectl run mysql-client --rm -it --image=mariadb:11-alpine -n diagnostic-db -- bash
mariadb -h mariadb-diag-mariadb-diagnostic -u root -p
# Wprowadź hasło: root (lub custom)
SHOW DATABASES;
USE testdb;
SHOW TABLES;
exit
```

### Usuwanie databases
```bash
helm uninstall redis-diag -n diagnostic-db
helm uninstall postgres-diag -n diagnostic-db
helm uninstall mariadb-diag -n diagnostic-db
```

---

## 5️⃣ Storage (MinIO) - Helm (1 obraz)

### Deployment

```bash
cd storage

# Deploy z domyślnymi wartościami
helm install minio-diag . -n diagnostic-storage --create-namespace

# Deploy z custom values
helm install minio-diag . -n diagnostic-storage \
  --set minio.rootUser="admin" \
  --set minio.rootPassword="admin123" \
  --set persistence.enabled=true \
  --set persistence.size=20Gi

# Upgrade
helm upgrade minio-diag . -n diagnostic-storage
```

### Weryfikacja
```bash
kubectl get pods,svc -n diagnostic-storage

# Port-forward do konsoli MinIO
kubectl port-forward -n diagnostic-storage svc/minio-diag-minio-diagnostic 9001:9001

# Otwórz w przeglądarce: http://localhost:9001
# Login: minioadmin / minioadmin (lub custom)

# Test API (w osobnym terminalu)
kubectl port-forward -n diagnostic-storage svc/minio-diag-minio-diagnostic 9000:9000

# Test z mc (MinIO Client)
kubectl run minio-client --rm -it --image=minio/mc -n diagnostic-storage -- bash
mc alias set myminio http://minio-diag-minio-diagnostic:9000 minioadmin minioadmin
mc ls myminio
mc mb myminio/test-bucket
mc cp /etc/hosts myminio/test-bucket/
mc ls myminio/test-bucket
exit
```

### Usuwanie
```bash
helm uninstall minio-diag -n diagnostic-storage
```

---

## 6️⃣ Registry (Docker Registry) - Helm (1 obraz)

### Deployment

```bash
cd registry

# Deploy
helm install registry-diag . -n diagnostic-registry --create-namespace

# Deploy z custom values
helm install registry-diag . -n diagnostic-registry \
  --set persistence.enabled=true \
  --set persistence.size=20Gi \
  --set service.type=NodePort

# Upgrade
helm upgrade registry-diag . -n diagnostic-registry
```

### Weryfikacja
```bash
kubectl get pods,svc -n diagnostic-registry

# Port-forward
kubectl port-forward -n diagnostic-registry svc/registry-diag-registry-diagnostic 5000:5000

# Test API (w osobnym terminalu)
curl http://localhost:5000/v2/_catalog

# Push image do registry (wymaga docker)
docker pull busybox:latest
docker tag busybox:latest localhost:5000/busybox:test
docker push localhost:5000/busybox:test

# Weryfikacja
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/busybox/tags/list
```

### Użycie w klastrze
```bash
# Pull image z registry
kubectl run test-registry --image=registry-diag-registry-diagnostic.diagnostic-registry:5000/busybox:test -n default
```

### Usuwanie
```bash
helm uninstall registry-diag -n diagnostic-registry
```

---

## 7️⃣ Service Mesh (Envoy Proxy) - Plain YAML (1 obraz)

### Deployment

```bash
cd service-mesh
kubectl apply -f envoy-proxy.yaml
```

### Weryfikacja
```bash
kubectl get pods,svc,cm -n diagnostic-mesh

# Test HTTP endpoint
kubectl run test-envoy --rm -it --image=curlimages/curl -n diagnostic-mesh -- \
  curl http://envoy-proxy:10000

# Test Envoy Admin Interface
kubectl port-forward -n diagnostic-mesh svc/envoy-proxy 9901:9901

# Otwórz w przeglądarce: http://localhost:9901
# Dostępne endpointy:
# http://localhost:9901/stats
# http://localhost:9901/config_dump
# http://localhost:9901/clusters
# http://localhost:9901/listeners
```

### Modyfikacja konfiguracji Envoy
```bash
# Edytuj ConfigMap
kubectl edit configmap envoy-config -n diagnostic-mesh

# Restart pod aby załadować nową konfigurację
kubectl rollout restart deployment envoy-proxy -n diagnostic-mesh
```

### Usuwanie
```bash
kubectl delete -f service-mesh/envoy-proxy.yaml
```

---

## 8️⃣ eBPF (bpftrace) - Plain YAML (1 obraz)

### Deployment

```bash
cd ebpf
kubectl apply -f bpftrace.yaml
```

### Weryfikacja
```bash
kubectl get pods,ds,sa,clusterrole,clusterrolebinding -n diagnostic-ebpf

# Sprawdź pod na każdym node
kubectl get pods -n diagnostic-ebpf -o wide

# Exec do pod
NODE_POD=$(kubectl get pods -n diagnostic-ebpf -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $NODE_POD -n diagnostic-ebpf -- bash
```

### Przykładowe użycie bpftrace
```bash
# Wewnątrz pod bpftrace

# Lista dostępnych probes
bpftrace -l

# Trace syscalls open
bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s %s\n", comm, str(args->filename)); }'

# Trace network connections
bpftrace -e 'kprobe:tcp_connect { printf("TCP connect by %s\n", comm); }'

# Count syscalls by process
bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'

# Trace file opens with filtering
bpftrace -e 'tracepoint:syscalls:sys_enter_openat /comm == "nginx"/ { printf("%s\n", str(args->filename)); }'

# CPU profiling
bpftrace -e 'profile:hz:99 { @[kstack] = count(); }'

# Exit
exit
```

### ⚠️ Uwaga bezpieczeństwa
- DaemonSet działa w trybie `privileged`
- Ma dostęp do `hostPID` i `hostNetwork`
- Używać TYLKO w środowiskach dev/test!

### Usuwanie
```bash
kubectl delete -f ebpf/bpftrace.yaml
```

---

## 9️⃣ K8s Core (Pause Container) - Plain YAML (1 obraz)

### Deployment

```bash
cd k8s-core
kubectl apply -f pause.yaml
```

### Weryfikacja
```bash
kubectl get pod pause-container -n diagnostic-core

# Sprawdź szczegóły
kubectl describe pod pause-container -n diagnostic-core

# Pause container nie ma shellu, więc exec nie zadziała
# Jest to minimalny kontener do testowania sieci/namespace
```

### Zastosowania
- Testowanie network policies
- Sprawdzanie DNS resolution
- Weryfikacja podstawowych mechanizmów K8s
- Placeholder dla testów multi-container pods

### Usuwanie
```bash
kubectl delete -f k8s-core/pause.yaml
```

---

## 🎯 Deployment wszystkiego naraz

### Deploy All
```bash
#!/bin/bash
# deploy-all.sh

# Namespaces
kubectl create namespace diagnostic-web --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-net --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-db --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-storage --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-registry --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-mesh --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-ebpf --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-core --dry-run=client -o yaml | kubectl apply -f -

# Kustomize - Web/HTTP
kubectl apply -k web-http/base/

# Plain YAML - Network Debug
kubectl apply -f network-debug/

# Plain YAML - DNS
kubectl apply -f dns/

# Helm - Databases
helm install redis-diag databases/redis -n diagnostic-db
helm install postgres-diag databases/postgres -n diagnostic-db
helm install mariadb-diag databases/mariadb -n diagnostic-db

# Helm - Storage
helm install minio-diag storage -n diagnostic-storage

# Helm - Registry
helm install registry-diag registry -n diagnostic-registry

# Plain YAML - Service Mesh
kubectl apply -f service-mesh/

# Plain YAML - eBPF
kubectl apply -f ebpf/

# Plain YAML - K8s Core
kubectl apply -f k8s-core/

echo "✅ All diagnostic tools deployed!"
```

### Cleanup All
```bash
#!/bin/bash
# cleanup-all.sh

# Kustomize
kubectl delete -k web-http/base/

# Plain YAML
kubectl delete -f network-debug/
kubectl delete -f dns/
kubectl delete -f service-mesh/
kubectl delete -f ebpf/
kubectl delete -f k8s-core/

# Helm
helm uninstall redis-diag -n diagnostic-db
helm uninstall postgres-diag -n diagnostic-db
helm uninstall mariadb-diag -n diagnostic-db
helm uninstall minio-diag -n diagnostic-storage
helm uninstall registry-diag -n diagnostic-registry

# Namespaces
kubectl delete namespace diagnostic-web
kubectl delete namespace diagnostic-net
kubectl delete namespace diagnostic-db
kubectl delete namespace diagnostic-storage
kubectl delete namespace diagnostic-registry
kubectl delete namespace diagnostic-mesh
kubectl delete namespace diagnostic-ebpf
kubectl delete namespace diagnostic-core

echo "✅ All diagnostic tools removed!"
```

---

## 📊 Przegląd wszystkich zasobów

```bash
# Lista wszystkich pods
kubectl get pods -A | grep diagnostic

# Lista wszystkich services
kubectl get svc -A | grep diagnostic

# Lista wszystkich namespaces
kubectl get ns | grep diagnostic

# Helm releases
helm list -A | grep diag

# Statystyki użycia
kubectl top pods -A | grep diagnostic
kubectl top nodes
```

---

## 🔧 Troubleshooting

### Problem: ImagePullBackOff
```bash
# Sprawdź logi
kubectl describe pod <pod-name> -n <namespace>

# Sprawdź dostęp do registry
kubectl run test-pull --rm -it --image=<problematic-image> -- sh
```

### Problem: CrashLoopBackOff
```bash
# Sprawdź logi
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Sprawdź events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Problem: Helm install fails
```bash
# Sprawdź wartości
helm lint databases/redis

# Dry-run
helm install redis-diag databases/redis -n diagnostic-db --dry-run --debug

# Template
helm template redis-diag databases/redis
```

### Problem: Kustomize build fails
```bash
# Sprawdź konfigurację
kubectl kustomize web-http/base/

# Debug
kubectl apply -k web-http/base/ --dry-run=client -o yaml
```

---

## 📚 Dokumentacja obrazów

| Obraz | Dokumentacja |
|-------|-------------|
| nginx | https://hub.docker.com/_/nginx |
| httpd | https://hub.docker.com/_/httpd |
| traefik/whoami | https://github.com/traefik/whoami |
| hello-app | https://github.com/GoogleCloudPlatform/kubernetes-engine-samples |
| httpbin | https://httpbin.org/ |
| echo-server | https://github.com/Ealenn/Echo-Server |
| netshoot | https://github.com/nicolaka/netshoot |
| network-multitool | https://github.com/Praqma/Network-MultiTool |
| redis | https://redis.io/docs/ |
| postgres | https://www.postgresql.org/docs/ |
| mariadb | https://mariadb.com/kb/en/documentation/ |
| minio | https://min.io/docs/minio/kubernetes/upstream/ |
| registry | https://docs.docker.com/registry/ |
| envoy | https://www.envoyproxy.io/docs/envoy/latest/ |
| bpftrace | https://github.com/iovisor/bpftrace |

---

## 🎓 Best Practices

1. **Namespace isolation**: Używaj osobnych namespace'ów dla różnych kategorii
2. **Resource limits**: Zawsze definiuj requests i limits
3. **Security**: Minimalizuj użycie `privileged` i `hostNetwork`
4. **Monitoring**: Integruj z Prometheus/Grafana
5. **Cleanup**: Regularnie usuwaj nieużywane zasoby
6. **Persistence**: Włączaj persistence tylko gdy potrzebna
7. **Secrets**: Używaj Kubernetes Secrets zamiast plain text passwords

---

## 📞 Support

Dla problemów i pytań:
- Sprawdź sekcję Troubleshooting powyżej
- Sprawdź logi: `kubectl logs <pod> -n <namespace>`
- Sprawdź events: `kubectl get events -n <namespace>`

---

## 📝 License

Ten zestaw manifestów jest dostępny na zasadach MIT License dla celów diagnostycznych i testowych.
