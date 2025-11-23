# ⚡ Quick Start - Natychmiastowe użycie

## 🚀 Szybki start - 3 komendy

```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments

# Opcja 1: Szybki smoke test (2 min)
./demo-quick-test.sh

# Opcja 2: Debugowanie aplikacji (5 min)
./demo-use-case.sh

# Opcja 3: Testowanie baz danych (7 min)
./demo-database-testing.sh
```

---

## 🎯 Przykład 1: "Muszę szybko przetestować connectivity"

### Krok 1: Deploy busybox (10 sekund)
```bash
kubectl create namespace diagnostic-net
kubectl apply -f network-debug/busybox.yaml
kubectl wait --for=condition=Ready pod/busybox -n diagnostic-net --timeout=60s
```

### Krok 2: Użyj (instant)
```bash
# Test DNS
kubectl exec busybox -n diagnostic-net -- nslookup google.com

# Test ping
kubectl exec busybox -n diagnostic-net -- ping -c 3 8.8.8.8

# Test port
kubectl exec busybox -n diagnostic-net -- nc -zv my-service 80
```

### Krok 3: Cleanup
```bash
kubectl delete -f network-debug/busybox.yaml
kubectl delete namespace diagnostic-net
```

**Total time: 1 minuta**

---

## 🎯 Przykład 2: "Muszę przetestować HTTP endpoint"

### Krok 1: Deploy curl
```bash
kubectl create namespace diagnostic-net
kubectl apply -f network-debug/curl.yaml
kubectl wait --for=condition=Ready pod/curl -n diagnostic-net --timeout=60s
```

### Krok 2: Test
```bash
# Test external
kubectl exec curl -n diagnostic-net -- curl -I https://google.com

# Test internal service
kubectl exec curl -n diagnostic-net -- curl http://my-service.my-namespace

# Test z headers
kubectl exec curl -n diagnostic-net -- curl -H "Authorization: Bearer token" http://api-service

# Download content
kubectl exec curl -n diagnostic-net -- curl -o /tmp/output.html http://my-service
```

### Krok 3: Cleanup
```bash
kubectl delete -f network-debug/curl.yaml
kubectl delete namespace diagnostic-net
```

**Total time: 1 minuta**

---

## 🎯 Przykład 3: "Muszę zbadać problem z bazą danych"

### Krok 1: Deploy netshoot (advanced tools)
```bash
kubectl create namespace diagnostic-net
kubectl apply -f network-debug/netshoot.yaml
kubectl wait --for=condition=Ready pod/netshoot -n diagnostic-net --timeout=60s
```

### Krok 2: Diagnoza
```bash
# Exec into pod
kubectl exec -it netshoot -n diagnostic-net -- bash

# W środku:
# Test port
nc -zv postgres-service 5432

# Install client (już zawiera większość tools)
apk add postgresql-client

# Test connection
psql -h postgres-service -U postgres -d mydb

# Network analysis
tcpdump -i any port 5432

# DNS debug
nslookup postgres-service
dig postgres-service

# Trace route
traceroute postgres-service

# Exit
exit
```

### Krok 3: Cleanup
```bash
kubectl delete -f network-debug/netshoot.yaml
kubectl delete namespace diagnostic-net
```

**Total time: 5 minut**

---

## 🎯 Przykład 4: "Potrzebuję Redis do testów"

### Krok 1: Deploy Redis (Helm)
```bash
kubectl create namespace diagnostic-db

helm install redis-test databases/redis -n diagnostic-db \
  --set redis.password="testpass"
```

### Krok 2: Użyj
```bash
# Port-forward (local access)
kubectl port-forward -n diagnostic-db svc/redis-test-redis-diagnostic 6379:6379 &

# Local redis-cli
redis-cli -h localhost
> ping
> SET mykey "Hello"
> GET mykey
> exit

# Lub z pod
kubectl run redis-client --rm -it --image=redis:7-alpine -n diagnostic-db -- bash
redis-cli -h redis-test-redis-diagnostic
> ping
```

### Krok 3: Cleanup
```bash
helm uninstall redis-test -n diagnostic-db
kubectl delete namespace diagnostic-db
```

**Total time: 2 minuty**

---

## 🎯 Przykład 5: "Chcę przetestować wszystkie web services"

### Krok 1: Deploy wszystkie HTTP tools (Kustomize)
```bash
kubectl create namespace diagnostic-web
kubectl apply -k web-http/base/
```

### Krok 2: Sprawdź co masz
```bash
kubectl get pods,svc -n diagnostic-web
```

Output:
```
NAME                              READY   STATUS    RESTARTS   AGE
pod/echo-server-xxx               1/1     Running   0          30s
pod/echoserver-xxx                1/1     Running   0          30s
pod/hello-app-xxx                 1/1     Running   0          30s
pod/httpbin-xxx                   1/1     Running   0          30s
pod/httpd-xxx                     1/1     Running   0          30s
pod/kuard-xxx                     1/1     Running   0          30s
pod/nginx-xxx                     1/1     Running   0          30s
pod/whoami-xxx                    1/1     Running   0          30s

NAME                  TYPE        CLUSTER-IP       PORT(S)    AGE
service/echo-server   ClusterIP   10.96.1.1        80/TCP     30s
service/httpbin       ClusterIP   10.96.1.2        80/TCP     30s
service/nginx         ClusterIP   10.96.1.3        80/TCP     30s
...
```

### Krok 3: Test każdego
```bash
# Deploy curl do testowania
kubectl create namespace diagnostic-net
kubectl apply -f network-debug/curl.yaml

# Test nginx
kubectl exec curl -n diagnostic-net -- curl http://nginx.diagnostic-web

# Test whoami (pokazuje request info)
kubectl exec curl -n diagnostic-net -- curl http://whoami.diagnostic-web

# Test httpbin (HTTP testing service)
kubectl exec curl -n diagnostic-net -- curl http://httpbin.diagnostic-web/get
kubectl exec curl -n diagnostic-net -- curl -X POST http://httpbin.diagnostic-web/post -d "test=data"
```

### Krok 4: Cleanup
```bash
kubectl delete -k web-http/base/
kubectl delete -f network-debug/curl.yaml
kubectl delete namespace diagnostic-web diagnostic-net
```

**Total time: 3 minuty**

---

## 📋 Cheatsheet - Najczęściej używane komendy

### Basic connectivity
```bash
# Ping
kubectl exec busybox -n diagnostic-net -- ping -c 3 <host>

# DNS
kubectl exec busybox -n diagnostic-net -- nslookup <service>

# Port check
kubectl exec busybox -n diagnostic-net -- nc -zv <host> <port>
```

### HTTP testing
```bash
# GET request
kubectl exec curl -n diagnostic-net -- curl http://<service>

# Headers only
kubectl exec curl -n diagnostic-net -- curl -I http://<service>

# POST request
kubectl exec curl -n diagnostic-net -- curl -X POST -d "data" http://<service>

# Verbose
kubectl exec curl -n diagnostic-net -- curl -v http://<service>
```

### Advanced diagnostics (netshoot)
```bash
# Interactive shell
kubectl exec -it netshoot -n diagnostic-net -- bash

# Network scan
kubectl exec netshoot -n diagnostic-net -- nmap -p 80,443 <host>

# Packet capture
kubectl exec netshoot -n diagnostic-net -- tcpdump -i any port 80

# Performance test
kubectl exec netshoot -n diagnostic-net -- iperf3 -c <host>
```

### Database testing
```bash
# Redis
kubectl run redis-test --rm -it --image=redis:alpine -- redis-cli -h <redis-host>

# PostgreSQL
kubectl run psql-test --rm -it --image=postgres:alpine -- psql -h <pg-host> -U <user>

# MySQL/MariaDB
kubectl run mysql-test --rm -it --image=mariadb:alpine -- mariadb -h <mysql-host> -u <user> -p
```

---

## 🎨 One-liners - Szybkie testy bez deploy

### Test bez tworzenia zasobów (--rm)
```bash
# Quick ping
kubectl run test-ping --rm -it --image=busybox -- ping -c 3 8.8.8.8

# Quick curl
kubectl run test-curl --rm -it --image=curlimages/curl -- curl https://google.com

# Quick DNS
kubectl run test-dns --rm -it --image=busybox -- nslookup kubernetes.default

# Quick psql
kubectl run test-psql --rm -it --image=postgres:alpine -- \
  psql -h mydb-service -U postgres
```

**Uwaga:** `--rm` automatycznie usuwa pod po zakończeniu!

---

## 🔥 Pro Tips

### 1. Alias dla szybszego użycia
```bash
# Dodaj do ~/.bashrc lub ~/.zshrc
alias k="kubectl"
alias kx="kubectl exec -it"
alias kgp="kubectl get pods"

# Użycie:
kx busybox -n diagnostic-net -- ping 8.8.8.8
```

### 2. Shell function dla testów
```bash
# Dodaj do ~/.bashrc
ktest() {
  kubectl run test-$RANDOM --rm -it --image=$1 -- ${@:2}
}

# Użycie:
ktest busybox ping 8.8.8.8
ktest curlimages/curl curl https://google.com
```

### 3. Persistent debug pod
```bash
# Utwórz raz, używaj wielokrotnie
kubectl run debug --image=nicolaka/netshoot -n default -- sleep infinity

# Użyj
kubectl exec -it debug -- bash

# Usuń kiedy skończysz
kubectl delete pod debug
```

---

## 📊 Które narzędzie kiedy używać?

| Zadanie | Narzędzie | Komenda |
|---------|-----------|---------|
| Basic ping/DNS | busybox | `kubectl exec busybox -- ping/nslookup` |
| HTTP requests | curl | `kubectl exec curl -- curl` |
| Advanced network | netshoot | `kubectl exec -it netshoot -- bash` |
| Database test | Helm charts | `helm install redis/postgres/mariadb` |
| Web testing | Kustomize web-http | `kubectl apply -k web-http/base/` |
| DNS debug | dnsutils | `kubectl exec dnsutils -- dig/nslookup` |

---

## ⚡ TL;DR - Absolutne minimum

```bash
# 1. Deploy busybox
kubectl create ns diagnostic-net
kubectl apply -f network-debug/busybox.yaml

# 2. Test cokolwiek
kubectl exec busybox -n diagnostic-net -- <your-command>

# 3. Cleanup
kubectl delete ns diagnostic-net
```

**To wszystko! Gotowe do użycia!** 🎉
