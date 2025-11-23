# 🧦 Demo App: Sock Shop (Weaveworks Microservices Demo)

**Źródło:** https://github.com/microservices-demo/microservices-demo

E-commerce aplikacja sprzedająca skarpetki - 8 mikrousług w różnych językach.

---

## 📦 Architektura

```
┌─────────────┐
│  Front-End  │ ← User Interface (Angular/Node.js)
└──────┬──────┘
       │
       ├──────────────┬──────────────┬─────────────┬──────────────┐
       ↓              ↓              ↓             ↓              ↓
┌──────────┐  ┌──────────────┐  ┌─────────┐  ┌─────────┐  ┌──────────┐
│ Catalogue│  │    Orders    │  │  Cart   │  │ Payment │  │ Shipping │
│          │  │              │  │         │  │         │  │          │
└────┬─────┘  └──────┬───────┘  └────┬────┘  └─────────┘  └──────────┘
     │               │               │
     ↓               ↓               ↓
┌─────────┐    ┌─────────┐    ┌─────────┐
│ MongoDB │    │  MySQL  │    │ MongoDB │
│Catalogue│    │  Orders │    │  Carts  │
└─────────┘    └─────────┘    └─────────┘
                                    │
                      ┌─────────────┴──────────────┐
                      ↓                            ↓
                ┌──────────┐                 ┌──────────┐
                │   User   │                 │ Queue    │
                │          │                 │ Master   │
                └────┬─────┘                 └──────────┘
                     │
                     ↓
               ┌──────────┐
               │ MongoDB  │
               │   User   │
               └──────────┘
```

---

## 🎯 Mikrousługi (8+ komponentów)

| # | Usługa | Język | Port | Funkcja | Database |
|---|--------|-------|------|---------|----------|
| 1 | **front-end** | Node.js | 8079 | Web UI | - |
| 2 | **catalogue** | Go | 80 | Produkty | MongoDB |
| 3 | **catalogue-db** | MongoDB | 27017 | Baza produktów | - |
| 4 | **carts** | Java | 80 | Koszyk | MongoDB |
| 5 | **carts-db** | MongoDB | 27017 | Baza koszyków | - |
| 6 | **orders** | Java | 80 | Zamówienia | MySQL |
| 7 | **orders-db** | MySQL | 3306 | Baza zamówień | - |
| 8 | **shipping** | Java | 80 | Wysyłka | - |
| 9 | **payment** | Go | 80 | Płatności | - |
| 10 | **user** | Go | 80 | Użytkownicy | MongoDB |
| 11 | **user-db** | MongoDB | 27017 | Baza użytkowników | - |
| 12 | **queue-master** | Java | 80 | Kolejka zadań | - |
| 13 | **rabbitmq** | RabbitMQ | 5672 | Message broker | - |

---

## 🚀 Quick Start

### 1. Deploy aplikacji
```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments/demo-app-sockshop

# Deploy all services
kubectl create namespace sock-shop
kubectl apply -f kubernetes-manifests.yaml

# Sprawdź status
kubectl get pods -n sock-shop

# Czekaj aż wszystkie będą Running (~3-5 min)
kubectl wait --for=condition=Ready pod --all -n sock-shop --timeout=300s
```

### 2. Dostęp do aplikacji
```bash
# Port-forward frontend
kubectl port-forward -n sock-shop svc/front-end 8080:80

# Otwórz w przeglądarce
# http://localhost:8080
```

### 3. Sprawdź serwisy
```bash
kubectl get svc -n sock-shop
```

---

## 🧪 Testowanie z diagnostic tools

### Quick test
```bash
# Deploy diagnostic tools
kubectl create namespace diagnostic-net
kubectl apply -f ../network-debug/curl.yaml

# Test front-end
kubectl exec curl -n diagnostic-net -- curl -I http://front-end.sock-shop:80

# Test catalogue
kubectl exec curl -n diagnostic-net -- curl http://catalogue.sock-shop:80/catalogue

# Test MongoDB
kubectl exec curl -n diagnostic-net -- nc -zv catalogue-db.sock-shop 27017

# Test MySQL
kubectl exec curl -n diagnostic-net -- nc -zv orders-db.sock-shop 3306

# Test RabbitMQ
kubectl exec curl -n diagnostic-net -- nc -zv rabbitmq.sock-shop 5672
```

---

## 📊 Resource Requirements

**Minimalne:**
- CPU: ~2 cores
- RAM: ~3 GB
- Nodes: 2-3 worker nodes

**Zalecane:**
- CPU: 4+ cores
- RAM: 6+ GB
- Nodes: 3+ worker nodes

---

## 🔧 Troubleshooting

### Problem: Pods Pending (MongoDB/MySQL)
```bash
# Sprawdź PVC
kubectl get pvc -n sock-shop

# Sprawdź storage class
kubectl get sc

# Sprawdź events
kubectl get events -n sock-shop --sort-by='.lastTimestamp'
```

**Fix:** Może brakować default storage class
```bash
# Check if you have default SC
kubectl get sc
# If not, patch one as default:
# kubectl patch sc <your-storage-class> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Problem: ImagePullBackOff
```bash
kubectl describe pod <pod-name> -n sock-shop
```

### Problem: Database connection errors
```bash
# Check database pods
kubectl get pods -n sock-shop | grep db

# Check logs
kubectl logs -n sock-shop catalogue-db
kubectl logs -n sock-shop orders-db
kubectl logs -n sock-shop user-db
```

---

## 📁 Pliki

```
demo-app-sockshop/
├── README.md                      # Ten plik
├── TESTING-GUIDE.md              # Przewodnik testowania
├── kubernetes-manifests.yaml      # Wszystkie manifesty
└── cleanup.sh                     # Skrypt czyszczenia
```

---

## 🧹 Cleanup

```bash
# Usuń aplikację
kubectl delete -f kubernetes-manifests.yaml
kubectl delete namespace sock-shop

# Lub użyj skryptu
./cleanup.sh
```

---

## 🔗 Linki

- **Repo:** https://github.com/microservices-demo/microservices-demo
- **Docs:** https://microservices-demo.github.io/
- **Architecture:** https://microservices-demo.github.io/docs/

---

## 🆚 Sock Shop vs Google Microservices Demo

| Feature | Sock Shop | Google Demo |
|---------|-----------|-------------|
| **Języki** | Go, Java, Node.js | Go, Python, Java, C#, Node.js |
| **Databases** | MongoDB, MySQL | Redis only |
| **Message Queue** | RabbitMQ | - |
| **Complexity** | Średnia | Średnia-wysoka |
| **Storage** | Persistent (PVC) | Stateless |
| **Best for** | Database testing | gRPC testing |

---

## 📝 Notatki

- Używa **REST API** (nie gRPC jak Google Demo)
- Wymaga **persistent storage** dla baz danych (MongoDB, MySQL)
- Ma **RabbitMQ** - dobry do testowania message queues
- Frontend w Node.js (Angular)
- Idealny do testowania **różnych baz danych**

---

## 🎯 Testing Endpoints

```bash
# Catalogue
curl http://front-end.sock-shop/catalogue

# Items
curl http://front-end.sock-shop/catalogue/3395a43e-2d88-40de-b95f-e00e1502085b

# Cart
curl http://front-end.sock-shop/cart

# Login
curl -X POST http://front-end.sock-shop/login -d '{"username":"user","password":"password"}'
```

---

**Status:** ✅ Ready to deploy
**Tested on:** k8s-master-1 (v1.29.15)
**Namespace:** sock-shop
