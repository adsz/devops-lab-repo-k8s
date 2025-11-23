#!/bin/bash
# Demo: Praktyczny use case diagnostyki w Kubernetes

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🎯 Use Case: Debugowanie problemu z aplikacją w K8s${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}🧹 Cleaning up demo resources...${NC}"
    kubectl delete namespace demo-app --ignore-not-found=true
    kubectl delete namespace diagnostic-net --ignore-not-found=true
    kubectl delete namespace diagnostic-web --ignore-not-found=true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Trap cleanup on exit
trap cleanup EXIT

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📦 KROK 1: Deploy aplikacji z problemem${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create namespace
kubectl create namespace demo-app

# Deploy broken app (typo w nazwie image)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
      - name: nginx
        image: nginxxxxx:alpine  # Celowy błąd!
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: broken-app-svc
  namespace: demo-app
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: broken-app
EOF

echo -e "${GREEN}✅ Aplikacja deployed${NC}"
sleep 3

echo ""
echo -e "${YELLOW}⚠️  Problem: Aplikacja nie działa!${NC}"
kubectl get pods -n demo-app
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 KROK 2: Deploy narzędzi diagnostycznych${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create namespaces
kubectl create namespace diagnostic-net

# Deploy debugging tools
echo "Deploying busybox..."
kubectl apply -f network-debug/busybox.yaml

echo "Deploying curl..."
kubectl apply -f network-debug/curl.yaml

echo "Deploying netshoot..."
kubectl apply -f network-debug/netshoot.yaml

echo ""
echo -e "${GREEN}✅ Narzędzia diagnostyczne deployed${NC}"
echo ""
echo "Czekam aż narzędzia będą ready..."
kubectl wait --for=condition=Ready pod/busybox -n diagnostic-net --timeout=60s || true
kubectl wait --for=condition=Ready pod/curl -n diagnostic-net --timeout=60s || true

echo ""
kubectl get pods -n diagnostic-net
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 KROK 3: Diagnostyka - Co jest nie tak?${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}3.1 Sprawdzam status pod...${NC}"
kubectl get pods -n demo-app
echo ""

echo -e "${YELLOW}3.2 Sprawdzam szczegóły pod (events)...${NC}"
kubectl describe pod -n demo-app -l app=broken-app | grep -A 10 "Events:"
echo ""

echo -e "${RED}❌ Problem znaleziony: ImagePullBackOff - zły obraz!${NC}"
echo ""

read -p "Naciśnij Enter aby naprawić problem..."

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 KROK 4: Naprawa aplikacji${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Fix the app
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine  # Poprawiony obraz!
        ports:
        - containerPort: 80
EOF

echo -e "${GREEN}✅ Aplikacja naprawiona - czekam aż wystartuje...${NC}"
sleep 5

kubectl get pods -n demo-app
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}✅ KROK 5: Weryfikacja - Czy działa?${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}5.1 Test z curl (z poziomu innego pod)...${NC}"
echo ""

# Wait for app to be ready
kubectl wait --for=condition=Ready pod -n demo-app -l app=broken-app --timeout=60s || true

# Test from curl pod
echo "$ kubectl exec curl -n diagnostic-net -- curl -s http://broken-app-svc.demo-app"
kubectl exec curl -n diagnostic-net -- curl -s http://broken-app-svc.demo-app | head -3
echo ""

echo -e "${GREEN}✅ Sukces! Aplikacja odpowiada!${NC}"
echo ""

echo -e "${YELLOW}5.2 Test DNS resolution...${NC}"
echo ""
echo "$ kubectl exec busybox -n diagnostic-net -- nslookup broken-app-svc.demo-app"
kubectl exec busybox -n diagnostic-net -- nslookup broken-app-svc.demo-app
echo ""

echo -e "${GREEN}✅ DNS działa poprawnie!${NC}"
echo ""

echo -e "${YELLOW}5.3 Test connectivity z netshoot (zaawansowany)...${NC}"
echo ""
echo "$ kubectl exec netshoot -n diagnostic-net -- curl -I http://broken-app-svc.demo-app"
kubectl exec netshoot -n diagnostic-net -- curl -I http://broken-app-svc.demo-app
echo ""

echo -e "${GREEN}✅ Wszystko działa!${NC}"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📚 Podsumowanie${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Użyte narzędzia:"
echo "  ✅ busybox  - Test DNS (nslookup)"
echo "  ✅ curl     - Test HTTP connectivity"
echo "  ✅ netshoot - Zaawansowana diagnostyka"
echo ""
echo "Kroki diagnostyki:"
echo "  1. Deploy aplikacji (z błędem)"
echo "  2. Deploy narzędzi diagnostycznych"
echo "  3. Identyfikacja problemu (kubectl describe)"
echo "  4. Naprawa (poprawienie image)"
echo "  5. Weryfikacja (curl, nslookup, connectivity)"
echo ""
echo -e "${GREEN}🎉 Demo zakończone!${NC}"
echo ""

read -p "Naciśnij Enter aby usunąć wszystkie zasoby demo..."
