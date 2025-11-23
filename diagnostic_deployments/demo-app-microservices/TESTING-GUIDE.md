# 🧪 Testing Guide - Diagnostic Tools vs Microservices Demo

Przewodnik testowania wszystkich 22 narzędzi diagnostycznych na aplikacji Google Microservices Demo.

---

## 🎯 Setup

### 1. Deploy aplikacji demo
```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments/demo-app-microservices
kubectl apply -f kubernetes-manifests.yaml
kubectl wait --for=condition=Ready pod --all --timeout=300s
```

### 2. Deploy narzędzi diagnostycznych
```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments

# Deploy selected tools
kubectl create namespace diagnostic-net
kubectl apply -f network-debug/
kubectl apply -f dns/
```

---

## 📦 Kategoria 1: Web/HTTP Testing (8 narzędzi)

### Test 1: curl - Basic HTTP connectivity
```bash
# Test frontend
kubectl exec curl -n diagnostic-net -- curl -I http://frontend.default:80

# Test product catalog API
kubectl exec curl -n diagnostic-net -- curl http://productcatalogservice.default:3550

# Test z verbose
kubectl exec curl -n diagnostic-net -- curl -v http://frontend.default:80

# Expected: HTTP 200 OK
```

### Test 2: httpbin - HTTP testing patterns
```bash
# Deploy httpbin jako proxy/tester
kubectl run httpbin --image=kennethreitz/httpbin --port=80

# Test POST request do checkout
kubectl exec curl -n diagnostic-net -- curl -X POST \
  http://checkoutservice.default:5050/checkout

# Test headers
kubectl exec curl -n diagnostic-net -- curl -H "User-Agent: Test" \
  http://frontend.default:80
```

### Test 3: whoami - Request inspection
```bash
# Deploy whoami
kubectl run whoami --image=traefik/whoami --port=80

# Forward request przez frontend
kubectl exec curl -n diagnostic-net -- curl http://whoami:80

# Sprawdź headers, IP, hostname
```

### Test 4: nginx - Static content serving
```bash
# Użyj nginx do serwowania statycznych assetów
kubectl run nginx --image=nginx:alpine --port=80

# Test performance
kubectl exec curl -n diagnostic-net -- \
  curl -w "@-" -o /dev/null -s http://nginx <<'EOF'
     time_namelookup:  %{time_namelookup}\n
        time_connect:  %{time_connect}\n
     time_appconnect:  %{time_appconnect}\n
       time_redirect:  %{time_redirect}\n
  time_starttransfer:  %{time_starttransfer}\n
                     ----------\n
          time_total:  %{time_total}\n
EOF
```

### Test 5-8: Echo servers - Response testing
```bash
# Test różne echo servers
kubectl exec curl -n diagnostic-net -- curl http://frontend.default:80 | head -20
```

---

## 📦 Kategoria 2: Network Debug (5 narzędzi)

### Test 1: busybox - Basic network tools
```bash
# Ping serwisów
kubectl exec busybox -n diagnostic-net -- ping -c 3 frontend.default

# Telnet test
kubectl exec busybox -n diagnostic-net -- telnet frontend.default 80

# Wget test
kubectl exec busybox -n diagnostic-net -- wget -O- http://productcatalogservice.default:3550
```

### Test 2: curl - Advanced HTTP
```bash
# Test wszystkich serwisów
for svc in frontend productcatalogservice cartservice currencyservice; do
  echo "Testing $svc..."
  kubectl exec curl -n diagnostic-net -- curl -s http://$svc.default | head -5
done

# Test connectivity matrix
kubectl exec curl -n diagnostic-net -- sh -c '
  for port in 80 3550 7070 7000; do
    nc -zv frontend.default $port 2>&1
  done
'
```

### Test 3: netshoot - Advanced diagnostics
```bash
# Interactive shell
kubectl exec -it netshoot -n diagnostic-net -- bash

# W środku:
# 1. nmap scan
nmap -p 80,3550,7070,7000 frontend.default

# 2. tcpdump
tcpdump -i any host frontend.default

# 3. iperf3 (wymaga iperf3 server)
# iperf3 -c frontend.default

# 4. mtr (traceroute)
mtr frontend.default

# 5. ss - socket stats
ss -tuln

# Exit
exit
```

### Test 4: network-multitool - Multi-purpose
```bash
# Test DNS
kubectl exec network-multitool -n diagnostic-net -- nslookup frontend.default

# Test HTTP
kubectl exec network-multitool -n diagnostic-net -- curl http://frontend.default:80

# Test connectivity
kubectl exec network-multitool -n diagnostic-net -- nc -zv redis-cart.default 6379
```

### Test 5: alpine - Lightweight testing
```bash
# Minimal test
kubectl exec alpine -n diagnostic-net -- wget -qO- http://frontend.default:80 | head -10

# Check DNS
kubectl exec alpine -n diagnostic-net -- nslookup frontend.default
```

---

## 📦 Kategoria 3: DNS Debugging

### dnsutils - DNS troubleshooting
```bash
# Basic lookup
kubectl exec dnsutils -n diagnostic-net -- nslookup frontend.default

# Dig detailed
kubectl exec dnsutils -n diagnostic-net -- dig frontend.default

# Dig all services
for svc in frontend productcatalogservice cartservice redis-cart; do
  echo "=== $svc ==="
  kubectl exec dnsutils -n diagnostic-net -- dig $svc.default.svc.cluster.local
done

# Reverse DNS
kubectl exec dnsutils -n diagnostic-net -- dig -x 10.96.0.1

# Check DNS server
kubectl exec dnsutils -n diagnostic-net -- nslookup kubernetes.default.svc.cluster.local
```

---

## 📦 Kategoria 4: Databases (Redis)

Demo app używa Redis dla cart service.

### Test Redis connectivity
```bash
# Deploy netshoot (ma redis-cli)
kubectl exec -it netshoot -n diagnostic-net -- bash

# W środku:
# Install redis-cli jeśli brak
apk add redis

# Connect to Redis
redis-cli -h redis-cart.default

# W redis-cli:
PING
# Expected: PONG

# Check keys
KEYS *

# Monitor commands
MONITOR

# Stats
INFO stats

# Exit
exit
```

### Test z custom Redis deployment
```bash
# Deploy Redis z Helm (z diagnostic tools)
kubectl create namespace diagnostic-db
helm install redis-test ../databases/redis -n diagnostic-db

# Test connection from netshoot
kubectl exec netshoot -n diagnostic-net -- redis-cli -h redis-test-redis-diagnostic.diagnostic-db PING
```

---

## 📦 Kategoria 5: Advanced Testing

### Scenario 1: Full connectivity test
```bash
#!/bin/bash
# Test all services connectivity

SERVICES=(
  "frontend:80"
  "productcatalogservice:3550"
  "cartservice:7070"
  "currencyservice:7000"
  "paymentservice:50051"
  "shippingservice:50051"
  "emailservice:8080"
  "checkoutservice:5050"
  "recommendationservice:8080"
  "adservice:9555"
  "redis-cart:6379"
)

for svc_port in "${SERVICES[@]}"; do
  svc=$(echo $svc_port | cut -d: -f1)
  port=$(echo $svc_port | cut -d: -f2)
  echo -n "Testing $svc:$port... "
  kubectl exec curl -n diagnostic-net -- nc -zv $svc.default $port 2>&1 | grep -q succeeded && echo "✅ OK" || echo "❌ FAIL"
done
```

### Scenario 2: DNS resolution matrix
```bash
#!/bin/bash
# Test DNS for all services

SERVICES=(frontend productcatalogservice cartservice currencyservice paymentservice shippingservice emailservice checkoutservice recommendationservice adservice redis-cart)

for svc in "${SERVICES[@]}"; do
  echo "=== $svc ==="
  kubectl exec dnsutils -n diagnostic-net -- nslookup $svc.default.svc.cluster.local | grep Address || echo "FAILED"
done
```

### Scenario 3: HTTP endpoint testing
```bash
#!/bin/bash
# Test HTTP endpoints

# Frontend
echo "Testing frontend..."
kubectl exec curl -n diagnostic-net -- curl -s http://frontend.default:80 | grep -q "Online Boutique" && echo "✅ Frontend OK" || echo "❌ Frontend FAIL"

# Product Catalog (gRPC - needs grpcurl)
echo "Testing product catalog..."
kubectl exec curl -n diagnostic-net -- nc -zv productcatalogservice.default 3550 && echo "✅ Product Catalog reachable" || echo "❌ FAIL"
```

### Scenario 4: Performance testing
```bash
# Load test frontend
kubectl exec curl -n diagnostic-net -- sh -c '
  for i in $(seq 1 100); do
    curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" http://frontend.default:80
  done
' | awk '{sum+=$2; count++} END {print "Avg response time:", sum/count, "s"}'
```

### Scenario 5: Network latency testing
```bash
# Ping all services
for svc in frontend productcatalogservice cartservice redis-cart; do
  echo "=== $svc ==="
  kubectl exec busybox -n diagnostic-net -- ping -c 5 $svc.default
done
```

---

## 🔍 Debugging Scenarios

### Scenario A: Service Not Responding
```bash
# 1. Check if service exists
kubectl get svc frontend

# 2. Check endpoints
kubectl get endpoints frontend

# 3. Check pod status
kubectl get pods -l app=frontend

# 4. Test DNS
kubectl exec dnsutils -n diagnostic-net -- nslookup frontend.default

# 5. Test connectivity
kubectl exec curl -n diagnostic-net -- curl -v http://frontend.default:80

# 6. Check logs
kubectl logs -l app=frontend --tail=50
```

### Scenario B: Slow Response
```bash
# 1. Measure response time
kubectl exec curl -n diagnostic-net -- curl -w "@-" -o /dev/null -s http://frontend.default:80 <<'EOF'
time_total: %{time_total}s
EOF

# 2. Check pod resources
kubectl top pod -l app=frontend

# 3. Check node resources
kubectl top nodes

# 4. Network latency
kubectl exec busybox -n diagnostic-net -- ping -c 10 frontend.default
```

### Scenario C: Intermittent Failures
```bash
# Run continuous test
kubectl exec curl -n diagnostic-net -- sh -c '
  while true; do
    status=$(curl -s -o /dev/null -w "%{http_code}" http://frontend.default:80)
    echo "$(date): $status"
    [ "$status" != "200" ] && echo "FAILED!" || echo "OK"
    sleep 1
  done
'

# Check pod restarts
kubectl get pods -w

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep frontend
```

---

## 📊 Complete Test Matrix

| Tool | Frontend | Product | Cart | Redis | Currency | Checkout |
|------|----------|---------|------|-------|----------|----------|
| curl | ✅ HTTP | ✅ gRPC test | ✅ | ❌ | ✅ | ✅ |
| busybox | ✅ ping | ✅ ping | ✅ ping | ✅ ping | ✅ ping | ✅ ping |
| netshoot | ✅ full | ✅ full | ✅ full | ✅ redis-cli | ✅ full | ✅ full |
| dnsutils | ✅ DNS | ✅ DNS | ✅ DNS | ✅ DNS | ✅ DNS | ✅ DNS |
| alpine | ✅ wget | ✅ wget | ⚠️ | ❌ | ✅ wget | ⚠️ |

**Legenda:**
- ✅ Fully supported
- ⚠️ Limited functionality
- ❌ Not applicable

---

## 🎯 Recommended Test Flow

### 1. Basic Connectivity (5 min)
```bash
# Deploy tools
kubectl apply -f ../network-debug/curl.yaml
kubectl apply -f ../network-debug/busybox.yaml

# Test
kubectl exec curl -n diagnostic-net -- curl http://frontend.default:80
kubectl exec busybox -n diagnostic-net -- ping -c 3 frontend.default
```

### 2. DNS Verification (2 min)
```bash
kubectl apply -f ../dns/dnsutils.yaml
kubectl exec dnsutils -n diagnostic-net -- nslookup frontend.default
```

### 3. Advanced Debugging (10 min)
```bash
kubectl apply -f ../network-debug/netshoot.yaml
kubectl exec -it netshoot -n diagnostic-net -- bash
# Interactive testing
```

### 4. Complete Validation (15 min)
```bash
# Run all scenarios A-E
# Document results
```

---

## 📝 Notes

- **gRPC services** (port 50051) wymagają `grpcurl` do testowania
- **Redis** wymaga `redis-cli` (dostępny w netshoot)
- **Frontend** jest jedynym HTTP REST endpoint
- Pozostałe usługi używają gRPC

---

**Happy Testing!** 🎉
