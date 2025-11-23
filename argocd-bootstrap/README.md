# ArgoCD Bootstrap

Ten folder zawiera bootstrapową konfigurację ArgoCD dla całego repozytorium.

## 🎯 Architektura

```
ArgoCD (ręczny install)
    ↓
Root App (ten folder)
    ↓
    ├─── Infrastructure ApplicationSet → cluster_deployments/*
    │         ├─── prometheus
    │         ├─── nginx-ingress
    │         ├─── cert-manager
    │         └─── velero
    │
    └─── Applications ApplicationSet → diagnostic_deployments/*
              ├─── demo-app-blog
              ├─── databases
              ├─── web-http
              └─── network-debug
```

## 📋 Wymagania

1. ArgoCD zainstalowane w klastrze
2. `kubectl` skonfigurowane
3. Dostęp do repozytorium Git

## 🚀 Bootstrap Procedure

### Krok 1: Zainstaluj ArgoCD (jeśli jeszcze nie)

```bash
# ArgoCD już powinno być zainstalowane
kubectl get pods -n argocd

# Jeśli nie, zainstaluj:
# kubectl apply -k cluster_deployments/argocd/
```

### Krok 2: Zastosuj Root App (TYLKO RAZ!)

```bash
# Z głównego folderu repo:
kubectl apply -f argocd-bootstrap/root-app.yaml
```

### Krok 3: Poczekaj na synchronizację

```bash
# Sprawdź root app
kubectl get application root-applicationsets -n argocd

# Root app utworzy ApplicationSets
kubectl get applicationsets -n argocd

# ApplicationSets utworzą aplikacje
kubectl get applications -n argocd
```

### Krok 4: Weryfikacja

```bash
# Sprawdź wszystkie aplikacje
kubectl get applications -n argocd | grep -E "infra-|app-"

# Infrastructure apps
kubectl get applications -n argocd | grep infra-

# Diagnostic apps
kubectl get applications -n argocd | grep app-
```

## 🔧 Co zostanie utworzone?

### Infrastructure ApplicationSet
Automatycznie tworzy aplikacje dla każdego folderu w `cluster_deployments/` (poza `argocd`):
- `infra-prometheus`
- `infra-nginx-ingress`
- `infra-cert-manager`
- `infra-velero`
- etc.

### Applications ApplicationSet
Automatycznie tworzy aplikacje dla każdego folderu w `diagnostic_deployments/`:
- `app-demo-app-blog`
- `app-databases`
- `app-web-http`
- `app-network-debug`
- etc.

## ⚠️ Ważne!

### ArgoCD Bootstrap Problem

ArgoCD **NIE MOŻE** zarządzać samym sobą przez ApplicationSet. Dlatego:

✅ **cluster_deployments/argocd/** jest WYKLUCZONE z ApplicationSet

❌ **Nie usuwaj** ręcznej instalacji ArgoCD

✅ **Root app** i **ApplicationSets** mogą być zarządzane przez ArgoCD

### Kolejność operacji

1. **Ręcznie**: Zainstaluj ArgoCD (`cluster_deployments/argocd/`)
2. **Ręcznie**: Zastosuj root app (`kubectl apply -f argocd-bootstrap/root-app.yaml`)
3. **Automatycznie**: Root app tworzy ApplicationSets
4. **Automatycznie**: ApplicationSets tworzą wszystkie aplikacje
5. **Automatycznie**: Git push → auto-sync wszystkich aplikacji

## 🔄 Dodawanie nowych aplikacji

### Nowa aplikacja diagnostyczna

```bash
# Utwórz folder
mkdir diagnostic_deployments/new-app
# Dodaj manifesty
cp -r template/* diagnostic_deployments/new-app/
# Commit + push
git add diagnostic_deployments/new-app
git commit -m "feat: add new-app"
git push
```

**Wynik**: ApplicationSet automatycznie utworzy `app-new-app` w ArgoCD!

### Nowy komponent infrastruktury

```bash
# Utwórz folder
mkdir cluster_deployments/new-component
# Dodaj manifesty
cp -r template/* cluster_deployments/new-component/
# Commit + push
git add cluster_deployments/new-component
git commit -m "feat: add new-component"
git push
```

**Wynik**: ApplicationSet automatycznie utworzy `infra-new-component` w ArgoCD!

## 🗑️ Usuwanie

### Usuń konkretną aplikację

```bash
# Usuń folder z git
rm -rf diagnostic_deployments/old-app
git commit -m "chore: remove old-app"
git push

# ApplicationSet automatycznie usunie app-old-app
```

### Usuń wszystko (OSTROŻNIE!)

```bash
# Usuń root app (kasuje wszystkie ApplicationSets i aplikacje)
kubectl delete application root-applicationsets -n argocd --cascade

# Lub usuń tylko ApplicationSets
kubectl delete applicationset cluster-infrastructure -n argocd
kubectl delete applicationset diagnostic-applications -n argocd
```

## 📊 Monitoring

### Sprawdź status wszystkich aplikacji

```bash
# Via kubectl
kubectl get applications -n argocd

# Via ArgoCD CLI
argocd app list

# Via UI
https://argocd.devops-lab.cloud
```

### Sprawdź ApplicationSets

```bash
kubectl get applicationsets -n argocd
kubectl describe applicationset cluster-infrastructure -n argocd
kubectl describe applicationset diagnostic-applications -n argocd
```

## 🐛 Troubleshooting

### Root app nie tworzy ApplicationSets

```bash
# Sprawdź logi
kubectl logs -n argocd deployment/argocd-application-controller | grep root-applicationsets

# Sprawdź status
kubectl get application root-applicationsets -n argocd -o yaml
```

### ApplicationSet nie tworzy aplikacji

```bash
# Sprawdź logi ApplicationSet controller
kubectl logs -n argocd deployment/argocd-applicationset-controller

# Sprawdź status ApplicationSet
kubectl get applicationset cluster-infrastructure -n argocd -o yaml
```

### Aplikacja nie synchronizuje się

```bash
# Sprawdź status aplikacji
argocd app get app-demo-app-blog

# Wymuś refresh
argocd app refresh app-demo-app-blog

# Wymuś sync
argocd app sync app-demo-app-blog
```

## 🔐 Security Best Practices

1. **Root app** - automatyczny sync (zarządza tylko ApplicationSets)
2. **Infrastructure** - manual prune, auto selfHeal (ostrożnie!)
3. **Applications** - full auto-sync (demo/dev środowiska)

Dla produkcji rozważ:
- Manual sync dla critical infra
- Approval workflows
- RBAC restrictions
- Separate projects per team

## 📚 Więcej informacji

- [ArgoCD ApplicationSet Docs](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [GitOps Best Practices](https://www.gitops.tech/)
