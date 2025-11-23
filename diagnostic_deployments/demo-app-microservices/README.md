# 🛍️ Demo App: Google Microservices (Online Boutique)

**Źródło:** https://github.com/GoogleCloudPlatform/microservices-demo

Kompletna aplikacja e-commerce z 11 mikrousługami - idealny target do testowania narzędzi diagnostycznych.

---

## 📦 Architektura

```
┌─────────────┐
│  Frontend   │ ← User Interface (web shop)
└──────┬──────┘
       │
       ├──────────────┬──────────────┬─────────────┬──────────────┐
       ↓              ↓              ↓             ↓              ↓
┌──────────┐  ┌──────────────┐  ┌─────────┐  ┌─────────┐  ┌──────────┐
│ Product  │  │ Recommendation│  │  Cart   │  │ Checkout│  │ Currency │
│ Catalog  │  │   Service     │  │ Service │  │ Service │  │ Service  │
└──────────┘  └──────────────┘  └─────────┘  └─────────┘  └──────────┘
       │              │              │             │              │
       └──────────────┴──────────────┴─────────────┴──────────────┘
                                     │
                      ┌──────────────┼──────────────┐
                      ↓              ↓              ↓
                ┌─────────┐    ┌─────────┐    ┌─────────┐
                │ Payment │    │Shipping │    │  Email  │
                │ Service │    │ Service │    │ Service │
                └─────────┘    └─────────┘    └─────────┘
                                     │
                                     ↓
                               ┌─────────┐
                               │  Redis  │
                               │  Cache  │
                               └─────────┘
```

---

## 🎯 Mikrousługi (11 komponentów)

| # | Usługa | Język | Port | Funkcja |
|---|--------|-------|------|---------|
| 1 | **frontend** | Go | 8080 | Web UI, agregacja |
| 2 | **productcatalogservice** | Go | 3550 | Lista produktów |
| 3 | **cartservice** | C# | 7070 | Koszyk zakupowy |
| 4 | **currencyservice** | Node.js | 7000 | Konwersja walut |
| 5 | **paymentservice** | Node.js | 50051 | Płatności |
| 6 | **shippingservice** | Go | 50051 | Koszty wysyłki |
| 7 | **emailservice** | Python | 8080 | Potwierdzenia email |
| 8 | **checkoutservice** | Go | 5050 | Checkout flow |
| 9 | **recommendationservice** | Python | 8080 | Rekomendacje |
| 10 | **adservice** | Java | 9555 | Reklamy |
| 11 | **redis-cart** | Redis | 6379 | Cache koszyka |

---

## 🚀 Quick Start

### 1. Deploy aplikacji
```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments/demo-app-microservices

# Deploy all services
kubectl apply -f kubernetes-manifests.yaml

# Sprawdź status
kubectl get pods -n default

# Czekaj aż wszystkie będą Running (~2-3 min)
kubectl wait --for=condition=Ready pod --all --timeout=300s
```

### 2. Dostęp do aplikacji
```bash
# Port-forward frontend
kubectl port-forward svc/frontend 8080:80

# Otwórz w przeglądarce
# http://localhost:8080
```

### 3. Sprawdź serwisy
```bash
kubectl get svc
```

---

## 🧪 Testowanie z diagnostic tools

Zobacz `TESTING-GUIDE.md` dla szczegółowych przykładów testowania każdego narzędzia.

**Szybki test:**
```bash
# Deploy diagnostic tools
kubectl create namespace diagnostic-net
kubectl apply -f ../network-debug/curl.yaml

# Test frontend
kubectl exec curl -n diagnostic-net -- curl -I http://frontend.default:80

# Test product catalog
kubectl exec curl -n diagnostic-net -- curl http://productcatalogservice.default:3550

# Test Redis
kubectl exec curl -n diagnostic-net -- nc -zv redis-cart.default 6379
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

### Problem: Pods Pending
```bash
# Sprawdź events
kubectl get events --sort-by='.lastTimestamp'

# Sprawdź resource usage
kubectl top nodes
kubectl top pods
```

**Fix:** Zmniejsz replicas lub resource limits

### Problem: ImagePullBackOff
```bash
kubectl describe pod <pod-name>
```

**Fix:** Sprawdź dostęp do registry (gcr.io)

### Problem: CrashLoopBackOff
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
```

---

## 📁 Pliki

```
demo-app-microservices/
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

# Lub użyj skryptu
./cleanup.sh
```

---

## 🔗 Linki

- **Repo:** https://github.com/GoogleCloudPlatform/microservices-demo
- **Docs:** https://github.com/GoogleCloudPlatform/microservices-demo/tree/main/docs
- **Architecture:** https://github.com/GoogleCloudPlatform/microservices-demo#architecture

---

## 📝 Notatki

- Wszystkie serwisy używają gRPC do komunikacji
- Frontend używa HTTP REST dla web UI
- Redis używany jako cache dla cart service
- Aplikacja nie wymaga persistent storage (stateless)
- Idealna do testowania service mesh (Istio/Linkerd)

---

**Status:** ✅ Ready to deploy
**Tested on:** k8s-master-1 (v1.29.15)
