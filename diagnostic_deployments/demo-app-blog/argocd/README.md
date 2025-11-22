# ArgoCD Applications for Blog Demo App

Ten folder zawiera definicje ArgoCD Application dla każdej metody deploymentu.

## 📋 Dostępne Aplikacje

| Aplikacja | Plik | Metoda | Namespace | Sync Policy |
|-----------|------|--------|-----------|-------------|
| blog-app-plain | `plain-yaml-app.yaml` | Plain YAML | demo-blog | Manual |
| blog-app-kustomize | `kustomize-app.yaml` | Kustomize (dev) | k-demo-blog | Manual |
| blog-app-helm | `helm-app.yaml` | Helm Chart | h-demo-blog | Manual |

## 🚀 Deployment

### Wdrożenie wybranej aplikacji

```bash
# Tylko Plain YAML
kubectl apply -f argocd/plain-yaml-app.yaml

# Tylko Kustomize
kubectl apply -f argocd/kustomize-app.yaml

# Tylko Helm
kubectl apply -f argocd/helm-app.yaml

# Wszystkie 3 (jeśli chcesz)
kubectl apply -f argocd/
```

### Synchronizacja w ArgoCD

Po utworzeniu Application, synchronizuj przez UI lub CLI:

```bash
# Sync przez CLI
argocd app sync blog-app-plain
argocd app sync blog-app-kustomize
argocd app sync blog-app-helm

# Lub przez UI
# https://argocd.devops-lab.cloud
```

### Auto-Sync (opcjonalne)

Domyślnie sync jest **manualny**. Aby włączyć auto-sync, odkomentuj sekcję `automated` w pliku Application:

```yaml
syncPolicy:
  automated:
    prune: true      # Auto-usuń zasoby
    selfHeal: true   # Auto-napraw drifty
```

## 🗑️ Usuwanie

### Usunięcie aplikacji z ArgoCD

```bash
# Usuń Application (wraz z zasobami)
kubectl delete -f argocd/plain-yaml-app.yaml
kubectl delete -f argocd/kustomize-app.yaml
kubectl delete -f argocd/helm-app.yaml

# Lub przez ArgoCD CLI
argocd app delete blog-app-plain --cascade
argocd app delete blog-app-kustomize --cascade
argocd app delete blog-app-helm --cascade
```

## 📊 Monitoring

```bash
# Status wszystkich aplikacji blog-app
argocd app list | grep blog-app

# Szczegóły aplikacji
argocd app get blog-app-plain
argocd app get blog-app-kustomize
argocd app get blog-app-helm

# Historia synchronizacji
argocd app history blog-app-plain
```

## 🎯 Use Cases

### Scenario 1: Testowanie jednej metody
```bash
# Wdróż tylko Kustomize
kubectl apply -f argocd/kustomize-app.yaml
argocd app sync blog-app-kustomize
```

### Scenario 2: Porównanie wszystkich metod
```bash
# Wdróż wszystkie 3
kubectl apply -f argocd/
argocd app sync blog-app-plain
argocd app sync blog-app-kustomize
argocd app sync blog-app-helm

# Sprawdź w UI różnice między deploymentami
```

### Scenario 3: Rolling update przez Git
```bash
# Zmień tag obrazu w repozytorium
# ArgoCD wykryje zmianę (OutOfSync)
# Ręcznie sync lub czekaj na auto-sync (jeśli włączony)
```

## 🔧 Konfiguracja

Wszystkie aplikacje używają:
- **Project**: default
- **Target Revision**: WIP (branch)
- **Repo**: git@github.com:adsz/devops-lab-repo-k8s.git
- **Sync Options**: CreateNamespace=true, PruneLast=true
- **Revision History**: 3 ostatnie

## 📝 Notes

- Każda aplikacja deployuje do osobnego namespace
- Manual sync policy zapewnia kontrolę nad deploymentem
- Finalizers zapewniają czyszczenie zasobów przy usuwaniu
- Wszystkie 3 metody mogą działać równocześnie (różne porty)
