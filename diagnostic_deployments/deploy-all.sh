#!/bin/bash
set -e

echo "🚀 Deploying all Kubernetes diagnostic tools..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create namespaces
echo -e "${BLUE}📦 Creating namespaces...${NC}"
kubectl create namespace diagnostic-web --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-net --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-db --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-storage --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-registry --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-mesh --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-ebpf --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace diagnostic-core --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespaces created${NC}"
echo ""

# Deploy Kustomize - Web/HTTP
echo -e "${BLUE}🌐 Deploying Web/HTTP testing tools (Kustomize)...${NC}"
kubectl apply -k web-http/base/
echo -e "${GREEN}✅ Web/HTTP tools deployed${NC}"
echo ""

# Deploy Plain YAML - Network Debug
echo -e "${BLUE}🔧 Deploying Network debug tools...${NC}"
kubectl apply -f network-debug/
echo -e "${GREEN}✅ Network debug tools deployed${NC}"
echo ""

# Deploy Plain YAML - DNS
echo -e "${BLUE}🌍 Deploying DNS debugging tools...${NC}"
kubectl apply -f dns/
echo -e "${GREEN}✅ DNS tools deployed${NC}"
echo ""

# Deploy Helm - Databases
echo -e "${BLUE}💾 Deploying Databases (Helm)...${NC}"
helm install redis-diag databases/redis -n diagnostic-db
helm install postgres-diag databases/postgres -n diagnostic-db
helm install mariadb-diag databases/mariadb -n diagnostic-db
echo -e "${GREEN}✅ Databases deployed${NC}"
echo ""

# Deploy Helm - Storage
echo -e "${BLUE}📦 Deploying Storage (MinIO - Helm)...${NC}"
helm install minio-diag storage -n diagnostic-storage
echo -e "${GREEN}✅ Storage deployed${NC}"
echo ""

# Deploy Helm - Registry
echo -e "${BLUE}🐳 Deploying Registry (Helm)...${NC}"
helm install registry-diag registry -n diagnostic-registry
echo -e "${GREEN}✅ Registry deployed${NC}"
echo ""

# Deploy Plain YAML - Service Mesh
echo -e "${BLUE}🕸️  Deploying Service Mesh (Envoy)...${NC}"
kubectl apply -f service-mesh/
echo -e "${GREEN}✅ Service Mesh deployed${NC}"
echo ""

# Deploy Plain YAML - eBPF
echo -e "${BLUE}🔬 Deploying eBPF tools (bpftrace)...${NC}"
kubectl apply -f ebpf/
echo -e "${GREEN}✅ eBPF tools deployed${NC}"
echo ""

# Deploy Plain YAML - K8s Core
echo -e "${BLUE}⚙️  Deploying K8s Core (pause)...${NC}"
kubectl apply -f k8s-core/
echo -e "${GREEN}✅ K8s Core deployed${NC}"
echo ""

echo -e "${GREEN}🎉 All diagnostic tools deployed successfully!${NC}"
echo ""
echo "📊 Summary:"
echo "  - 8 Web/HTTP testing containers"
echo "  - 5 Network debugging tools"
echo "  - 1 DNS debugging tool"
echo "  - 3 Databases (Redis, PostgreSQL, MariaDB)"
echo "  - 1 Storage system (MinIO)"
echo "  - 1 Container registry"
echo "  - 1 Service mesh proxy (Envoy)"
echo "  - 1 eBPF tracing tool (bpftrace)"
echo "  - 1 K8s core container (pause)"
echo ""
echo "Total: 22 diagnostic images deployed!"
echo ""
echo "📋 To view all resources:"
echo "  kubectl get pods -A | grep diagnostic"
echo ""
echo "📖 For usage instructions, see README.md"
