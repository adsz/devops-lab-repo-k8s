# 🎯 Demo Use Cases - Praktyczne przykłady użycia

Ten folder zawiera **3 praktyczne demo skrypty** pokazujące jak używać narzędzi diagnostycznych w rzeczywistych scenariuszach.

---

## 📋 Dostępne Demo

### 1️⃣ **demo-quick-test.sh** - Szybki smoke test
⏱️ **Czas:** ~2 minuty

**Co robi:**
- Deploy minimalnego zestawu narzędzi (busybox, curl)
- Wykonuje 5 podstawowych testów:
  - ✅ Ping external host (8.8.8.8)
  - ✅ DNS resolution (kubernetes.default)
  - ✅ HTTP request (google.com)
  - ✅ K8s API access
  - ✅ Pod-to-Pod communication
- Automatic cleanup

**Kiedy użyć:**
- Sprawdzenie czy narzędzia działają
- Weryfikacja podstawowej connectivity w klastrze
- Szybki health check

**Uruchomienie:**
```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments
./demo-quick-test.sh
```

---

### 2️⃣ **demo-use-case.sh** - Debugowanie problemu z aplikacją
⏱️ **Czas:** ~5 minut

**Co robi:**
1. Deploy aplikacji z **celowym błędem** (ImagePullBackOff)
2. Deploy narzędzi diagnostycznych (busybox, curl, netshoot)
3. **Diagnostyka** - identyfikacja problemu
4. **Naprawa** - poprawienie błędu
5. **Weryfikacja** - testy działania

**Narzędzia użyte:**
- `kubectl describe` - Znajdowanie błędów
- `curl` - Test HTTP connectivity
- `busybox` - Test DNS resolution
- `netshoot` - Zaawansowana diagnostyka

**Czego się nauczysz:**
- Jak debugować ImagePullBackOff
- Jak używać curl do testowania serwisów
- Jak weryfikować DNS w klastrze
- Workflow: problem → diagnoza → naprawa → weryfikacja

**Uruchomienie:**
```bash
./demo-use-case.sh
```

---

### 3️⃣ **demo-database-testing.sh** - Testowanie baz danych
⏱️ **Czas:** ~7 minut

**Co robi:**
1. Deploy **Redis** i **PostgreSQL** przez Helm
2. Deploy network tools (busybox, netshoot)
3. Test connectivity do Redis:
   - Port check (nc)
   - redis-cli (PING, SET, GET)
4. Test connectivity do PostgreSQL:
   - Port check (nc)
   - psql (CREATE TABLE, INSERT, SELECT)
5. Zaawansowana diagnostyka sieci

**Narzędzia użyte:**
- `Helm` - Deploy databases
- `busybox` - Basic connectivity (nc, nslookup)
- `netshoot` - Advanced testing (redis-cli, psql)

**Czego się nauczysz:**
- Jak deploy'ować bazy danych z Helm
- Jak testować connectivity do databases
- Jak używać redis-cli i psql z pod'a
- Jak weryfikować DNS i endpoints

**Uruchomienie:**
```bash
./demo-database-testing.sh
```

---

## 🎓 Tutorial: Krok po kroku

### Scenariusz 1: Masz problem z aplikacją

```bash
# 1. Uruchom demo z problemem
./demo-use-case.sh

# Demo pokaże:
# - Jak znaleźć problem (ImagePullBackOff)
# - Jak go naprawić (poprawienie image)
# - Jak zweryfikować że działa (curl, nslookup)
```

**Output:**
```
🔍 KROK 3: Diagnostyka - Co jest nie tak?

3.1 Sprawdzam status pod...
NAME                          READY   STATUS             RESTARTS   AGE
broken-app-5f8d9c6b8d-7xk2m   0/1     ImagePullBackOff   0          30s

3.2 Sprawdzam szczegóły pod (events)...
Events:
  Type     Reason     Message
  ----     ------     -------
  Warning  Failed     Failed to pull image "nginxxxxx:alpine": not found

❌ Problem znaleziony: ImagePullBackOff - zły obraz!
```

---

### Scenariusz 2: Testujesz nowe bazy danych

```bash
# 1. Uruchom demo baz danych
./demo-database-testing.sh

# Demo pokaże:
# - Deploy Redis + PostgreSQL przez Helm
# - Test połączenia (nc, redis-cli, psql)
# - Wykonanie operacji (SET/GET, CREATE/INSERT/SELECT)
```

**Output:**
```
🔍 KROK 3: Test połączenia do Redis

Testing Redis at: redis-demo-redis-diagnostic.diagnostic-db
PONG

Setting test key...
OK

Getting test key...
"Hello from diagnostic tools"

✅ Redis działa poprawnie!
```

---

### Scenariusz 3: Szybki health check

```bash
# 1. Uruchom quick test
./demo-quick-test.sh

# Demo wykonuje 5 testów w ~2 minuty
```

---

## 📊 Porównanie demo

| Demo | Czas | Narzędzia | Poziom | Use Case |
|------|------|-----------|--------|----------|
| **quick-test** | 2 min | busybox, curl | Beginner | Health check, smoke test |
| **use-case** | 5 min | busybox, curl, netshoot | Intermediate | Debugowanie aplikacji |
| **database-testing** | 7 min | Helm, busybox, netshoot | Advanced | Testowanie databases |

---

## 🛠️ Customizacja demo

### Modyfikacja demo-use-case.sh

**Zmień typ błędu:**
```bash
# Zamiast ImagePullBackOff, użyj CrashLoopBackOff
containers:
- name: nginx
  image: nginx:alpine
  command: ["sh", "-c", "exit 1"]  # Celowy crash
```

**Dodaj więcej testów:**
```bash
# Test dodatkowego endpoint
echo "Test /health endpoint..."
kubectl exec curl -n diagnostic-net -- \
  curl http://broken-app-svc.demo-app/health
```

### Modyfikacja demo-database-testing.sh

**Dodaj MariaDB:**
```bash
echo "Deploy MariaDB..."
helm install mariadb-demo databases/mariadb -n diagnostic-db \
  --set mariadb.rootPassword="root123"
```

**Test performance:**
```bash
# Dodaj benchmark Redis
kubectl exec netshoot -n diagnostic-net -- \
  redis-benchmark -h redis-demo-redis-diagnostic.diagnostic-db -q
```

---

## 🔍 Debugowanie demo

### Problem: Demo się crashuje

```bash
# Sprawdź logi
kubectl logs -n diagnostic-net busybox
kubectl describe pod busybox -n diagnostic-net

# Sprawdź czy namespace istnieją
kubectl get ns | grep diagnostic

# Sprawdź czy tools są deployed
kubectl get pods -A | grep diagnostic
```

### Problem: Helm install fails

```bash
# Sprawdź czy Helm działa
helm version

# Sprawdź czy chart jest poprawny
helm lint databases/redis

# Debug Helm install
helm install redis-demo databases/redis -n diagnostic-db --dry-run --debug
```

### Problem: Network connectivity fails

```bash
# Sprawdź network policies
kubectl get networkpolicies -A

# Sprawdź DNS
kubectl exec busybox -n diagnostic-net -- nslookup kubernetes.default

# Sprawdź czy CoreDNS działa
kubectl get pods -n kube-system | grep coredns
```

---

## 📚 Kolejne kroki

Po wykonaniu demo:

1. **Eksperymentuj** - Modyfikuj skrypty, dodawaj własne testy
2. **Dokumentuj** - Zapisuj co działa, co nie działa
3. **Twórz własne** - Stwórz demo dla swojego use case
4. **Dziel się** - Pokaż innym w zespole

---

## 🎯 Real-world Use Cases

### Use Case 1: Pod nie może połączyć się z external API
```bash
# Deploy curl pod
kubectl apply -f network-debug/curl.yaml

# Test connectivity
kubectl exec curl -n diagnostic-net -- curl -v https://api.example.com

# Jeśli fail, sprawdź:
# - DNS: kubectl exec curl -n diagnostic-net -- nslookup api.example.com
# - Network policies: kubectl get networkpolicies -A
# - Egress rules
```

### Use Case 2: Service discovery nie działa
```bash
# Deploy dnsutils
kubectl apply -f dns/dnsutils.yaml

# Test DNS
kubectl exec dnsutils -n diagnostic-net -- nslookup my-service.my-namespace

# Jeśli fail:
# - Sprawdź CoreDNS: kubectl logs -n kube-system -l k8s-app=kube-dns
# - Sprawdź service: kubectl get svc -n my-namespace
# - Sprawdź endpoints: kubectl get endpoints -n my-namespace
```

### Use Case 3: Database connection timeout
```bash
# Deploy netshoot
kubectl apply -f network-debug/netshoot.yaml

# Test port connectivity
kubectl exec netshoot -n diagnostic-net -- nc -zv db-host 5432

# Test latency
kubectl exec netshoot -n diagnostic-net -- ping db-host

# Sprawdź routing
kubectl exec netshoot -n diagnostic-net -- traceroute db-host
```

---

## 💡 Tips & Tricks

1. **Używaj `--rm`** dla jednorazowych testów:
   ```bash
   kubectl run test --rm -it --image=busybox -- ping 8.8.8.8
   ```

2. **Port-forward** dla local testing:
   ```bash
   kubectl port-forward -n diagnostic-db svc/redis-demo 6379:6379
   redis-cli -h localhost
   ```

3. **Exec multiple commands**:
   ```bash
   kubectl exec busybox -n diagnostic-net -- sh -c "nslookup google.com && ping -c 3 8.8.8.8"
   ```

4. **Save output** do pliku:
   ```bash
   kubectl exec curl -n diagnostic-net -- curl https://google.com > output.html
   ```

---

**🎉 Happy debugging!**
