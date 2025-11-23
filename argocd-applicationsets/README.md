# ArgoCD ApplicationSets

Ten folder zawiera ApplicationSets które automatycznie tworzą ArgoCD Applications dla całego repozytorium.

## 📁 Struktura

```
argocd-applicationsets/
├── infra-applicationset.yaml    # cluster_deployments/* (bez argocd)
└── apps-applicationset.yaml     # diagnostic_deployments/*
```

## 🎯 Infrastructure ApplicationSet

**Plik**: `infra-applicationset.yaml`

**Zarządza**: `cluster_deployments/*` (wykluczając `argocd/`)

**Tworzy aplikacje**:
- `infra-prometheus` → cluster_deployments/prometheus/
- `infra-nginx-ingress` → cluster_deployments/nginx-ingress/
- `infra-cert-manager` → cluster_deployments/cert-manager/
- `infra-velero` → cluster_deployments/velero/
- etc.

**Polityka sync**:
- `automated.prune: false` - bezpieczne dla infrastruktury
- `automated.selfHeal: true` - auto-naprawa driftów
- Ręczny prune dla kontroli

**Wykluczenia**:
- `cluster_deployments/argocd/` - bootstrap problem

## 🚀 Applications ApplicationSet

**Plik**: `apps-applicationset.yaml`

**Zarządza**: `diagnostic_deployments/*`

**Tworzy aplikacje**:
- `app-demo-app-blog` → diagnostic_deployments/demo-app-blog/
- `app-databases` → diagnostic_deployments/databases/
- `app-web-http` → diagnostic_deployments/web-http/
- `app-network-debug` → diagnostic_deployments/network-debug/
- etc.

**Polityka sync**:
- `automated.prune: true` - agresywne zarządzanie
- `automated.selfHeal: true` - auto-sync
- Pełna automatyzacja dla demo/dev apps

**Wykluczenia**:
- `*.sh` - skrypty
- `*.md` - dokumentacja

## 🔄 Jak to działa?

### 1. Git Directory Generator

ApplicationSets używają Git Directory Generator do automatycznego wykrywania folderów:

```yaml
generators:
- git:
    repoURL: https://github.com/adsz/devops-lab-repo-k8s.git
    revision: WIP
    directories:
    - path: cluster_deployments/*
      exclude: cluster_deployments/argocd
```

### 2. Template Application

Dla każdego znalezionego folderu, ApplicationSet tworzy Application:

```yaml
template:
  metadata:
    name: 'infra-{{.path.basename}}'  # infra-prometheus
  spec:
    source:
      path: '{{.path.path}}'           # cluster_deployments/prometheus
```

### 3. Auto-Sync

Gdy zrobisz `git push` ze zmianami:
1. ArgoCD wykrywa nowy commit (co 3 min)
2. ApplicationSet regeneruje Applications
3. Aplikacje synchronizują się automatycznie

## 📝 Przykłady

### Dodanie nowej aplikacji

```bash
# 1. Utwórz folder
mkdir diagnostic_deployments/my-new-app

# 2. Dodaj manifesty
cat <<EOF > diagnostic_deployments/my-new-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest
EOF

# 3. Commit i push
git add diagnostic_deployments/my-new-app
git commit -m "feat: add my-new-app"
git push

# 4. ApplicationSet automatycznie utworzy app-my-new-app!
# Sprawdź po ~3 minutach:
kubectl get application app-my-new-app -n argocd
```

### Dodanie nowego komponentu infrastruktury

```bash
# 1. Utwórz folder
mkdir cluster_deployments/grafana

# 2. Dodaj manifesty
cp -r template/* cluster_deployments/grafana/

# 3. Commit i push
git add cluster_deployments/grafana
git commit -m "feat: add grafana"
git push

# 4. ApplicationSet automatycznie utworzy infra-grafana!
kubectl get application infra-grafana -n argocd
```

## 🔧 Customizacja

### Zmiana sync policy

Edytuj plik ApplicationSet i zmień:

```yaml
syncPolicy:
  automated:
    prune: true   # true = auto delete, false = manual
    selfHeal: true # true = auto sync, false = manual
```

### Dodanie wykluczeń

Dodaj do sekcji `directories`:

```yaml
directories:
- path: diagnostic_deployments/*
  exclude: diagnostic_deployments/*.sh
  exclude: diagnostic_deployments/temp-*
  exclude: diagnostic_deployments/old-*
```

### Zmiana namespace pattern

Domyślnie każda app idzie do namespace o nazwie folderu. Zmień w `template`:

```yaml
destination:
  namespace: 'custom-{{.path.basename}}'
```

## 📊 Monitoring

### Sprawdź ApplicationSets

```bash
# Lista ApplicationSets
kubectl get applicationsets -n argocd

# Szczegóły Infrastructure ApplicationSet
kubectl describe applicationset cluster-infrastructure -n argocd

# Szczegóły Applications ApplicationSet
kubectl describe applicationset diagnostic-applications -n argocd
```

### Sprawdź wygenerowane aplikacje

```bash
# Wszystkie aplikacje
kubectl get applications -n argocd

# Tylko infrastructure
kubectl get applications -n argocd | grep infra-

# Tylko applications
kubectl get applications -n argocd | grep app-
```

### Sprawdź logi ApplicationSet controller

```bash
kubectl logs -n argocd deployment/argocd-applicationset-controller -f
```

## 🐛 Troubleshooting

### ApplicationSet nie tworzy aplikacji

**Problem**: Nowy folder w git, ale aplikacja się nie pojawia

**Rozwiązanie**:
```bash
# Sprawdź czy ApplicationSet widzi folder
kubectl get applicationset cluster-infrastructure -n argocd -o yaml | grep -A 10 generators

# Wymuś refresh (usuń i utwórz ponownie ApplicationSet)
kubectl delete applicationset cluster-infrastructure -n argocd
kubectl apply -f argocd-applicationsets/infra-applicationset.yaml
```

### Aplikacja ma błędny path

**Problem**: Application wskazuje na zły folder

**Rozwiązanie**: Sprawdź template path w ApplicationSet:
```yaml
source:
  path: '{{.path.path}}'  # Musi być .path.path nie .path
```

### ArgoCD próbuje zarządzać argocd/

**Problem**: `infra-argocd` aplikacja się pojawia mimo exclude

**Rozwiązanie**: Sprawdź exclude pattern:
```yaml
directories:
- path: cluster_deployments/*
  exclude: cluster_deployments/argocd  # Dokładna ścieżka
```

## 🔐 Security

### Infrastructure ApplicationSet
- ✅ Manual prune - nie kasuje przypadkowo
- ✅ Auto selfHeal - naprawia zmiany ręczne
- ✅ Retry with backoff - stabilność
- ✅ Exclude ArgoCD - bezpieczeństwo

### Applications ApplicationSet
- ✅ Auto prune - czyste środowisko
- ✅ Auto selfHeal - zawsze zgodne z git
- ✅ ApplyOutOfSyncOnly - wydajność
- ⚠️  Full automation - tylko dla dev/demo

## 📚 Więcej informacji

- [ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [Git Directory Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/)
- [Template Fields](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Template/)
