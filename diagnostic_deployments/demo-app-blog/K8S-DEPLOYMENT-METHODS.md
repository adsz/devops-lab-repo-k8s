# Blog App - 3 Metody Deploymentu K8s ✅

## Struktura

```
k8s/
├── plain-yaml/          # ✅ Czysty YAML
│   ├── namespace.yaml
│   ├── *-deployment.yaml
│   ├── *-service.yaml
│   └── kustomization.yaml
│
├── kustomize/          # ✅ Kustomize
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── *.yaml
│   └── overlays/
│       ├── dev/
│       │   └── kustomization.yaml
│       └── prod/
│           └── kustomization.yaml
│
└── helm/               # ✅ Helm Chart
    └── blog-app/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── namespace.yaml
            ├── *-deployment.yaml
            ├── *-service.yaml
            ├── *-configmap.yaml
            └── *-secret.yaml
```

## Namespace, Porty i Prefiksy

| Metoda | Namespace | Frontend NodePort | API NodePort | Name Prefix | Replicas |
|--------|-----------|-------------------|--------------|-------------|----------|
| **Plain YAML** | demo-blog | 30080 | 30050 | brak | 2/2 |
| **Kustomize Dev** | k-demo-blog | 30081 | 30051 | k- | 2/2 |
| **Kustomize Prod** | k-demo-blog | 30081 | 30051 | k- | 3/3 |
| **Helm** | h-demo-blog | 30082 | 30052 | h- | 2/2 |

## Deploy Commands

### 1. Plain YAML
```bash
cd k8s/plain-yaml
kubectl apply -f .

# Verify
kubectl get pods -n demo-blog
kubectl get svc -n demo-blog
```

### 2. Kustomize

**Dev Environment:**
```bash
kubectl apply -k k8s/kustomize/overlays/dev/

# Verify
kubectl get pods -n k-demo-blog
```

**Prod Environment (3 replicas):**
```bash
kubectl apply -k k8s/kustomize/overlays/prod/

# Verify
kubectl get pods -n k-demo-blog
```

### 3. Helm

**Install:**
```bash
helm install blog-app-helm k8s/helm/blog-app/ \
  --namespace h-demo-blog \
  --create-namespace

# Verify
helm list -n h-demo-blog
kubectl get pods -n h-demo-blog
```

**Customize values:**
```bash
helm install blog-app-helm k8s/helm/blog-app/ \
  --namespace h-demo-blog \
  --create-namespace \
  --set frontend.replicas=3 \
  --set api.replicas=3
```

**Upgrade:**
```bash
helm upgrade blog-app-helm k8s/helm/blog-app/ -n h-demo-blog
```

## Deploy All 3 Methods Simultaneously

```bash
./deploy-all-3-methods.sh
```

Możesz mieć wszystkie 3 wersje uruchomione jednocześnie!

## Access URLs

| Method | Frontend | API |
|--------|----------|-----|
| Plain YAML | http://192.168.0.190:30080 | http://192.168.0.190:30050 |
| Kustomize | http://192.168.0.190:30081 | http://192.168.0.190:30051 |
| Helm | http://192.168.0.190:30082 | http://192.168.0.190:30052 |

## Cleanup

```bash
# Plain YAML
kubectl delete namespace demo-blog

# Kustomize
kubectl delete namespace k-demo-blog

# Helm
helm uninstall blog-app-helm -n h-demo-blog
kubectl delete namespace h-demo-blog

# All at once
kubectl delete namespace demo-blog k-demo-blog h-demo-blog
```

## Porównanie Metod

### Plain YAML
✅ **Plusy:**
- Najprostsze - bezpośrednie pliki YAML
- Łatwe debugowanie
- Brak dodatkowych narzędzi

❌ **Minusy:**
- Duplikacja kodu
- Trudne zarządzanie wieloma środowiskami
- Brak parametryzacji

### Kustomize
✅ **Plusy:**
- Built-in w kubectl (od 1.14+)
- Overlays dla różnych środowisk
- Patches i transformacje
- Brak template'ów

❌ **Minusy:**
- Ograniczona logika
- Mniej elastyczne niż Helm

### Helm
✅ **Plusy:**
- Pełna parametryzacja (values.yaml)
- Versioning i rollback
- Repozytoria chart'ów
- Hooks i lifecycle management
- Najpotężniejsze

❌ **Minusy:**
- Wymaga instalacji Helm
- Template syntax może być skomplikowany
- Debugging trudniejszy

## Kiedy Używać Której Metody?

**Plain YAML:**
- Learning / proof-of-concept
- Proste single-environment deploymenty
- Gdy nie potrzebujesz parametryzacji

**Kustomize:**
- Multiple environments (dev/staging/prod)
- Gdy chcesz uniknąć template'ów
- GitOps workflows (ArgoCD, Flux)
- Overlay-based configuration

**Helm:**
- Production deployments
- Aplikacje z wieloma konfiguracjami
- Reusable charts
- Gdy potrzebujesz versioning i rollback
- Gdy instalujesz z public/private repo

## Status

✅ **Wszystkie 3 metody gotowe i przetestowane!**

- ✅ Plain YAML - działa (obecnie deployed)
- ✅ Kustomize - gotowy (base + dev/prod overlays)
- ✅ Helm - gotowy (pełny chart z templates)

---

**Test All Methods:**
```bash
# Deploy all 3
./deploy-all-3-methods.sh

# Sprawdź wszystkie
kubectl get pods --all-namespaces | grep blog

# Test każdego
curl http://192.168.0.190:30080  # Plain
curl http://192.168.0.190:30081  # Kustomize  
curl http://192.168.0.190:30082  # Helm
```
