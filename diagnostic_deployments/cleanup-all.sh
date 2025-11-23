#!/bin/bash
set -e

echo "🧹 Cleaning up all Kubernetes diagnostic tools..."
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Confirmation
read -p "⚠️  Are you sure you want to remove ALL diagnostic tools? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi
echo ""

# Delete Kustomize
echo -e "${YELLOW}🌐 Removing Web/HTTP testing tools...${NC}"
kubectl delete -k web-http/base/ --ignore-not-found=true
echo -e "${RED}✅ Web/HTTP tools removed${NC}"
echo ""

# Delete Plain YAML - Network Debug
echo -e "${YELLOW}🔧 Removing Network debug tools...${NC}"
kubectl delete -f network-debug/ --ignore-not-found=true
echo -e "${RED}✅ Network debug tools removed${NC}"
echo ""

# Delete Plain YAML - DNS
echo -e "${YELLOW}🌍 Removing DNS debugging tools...${NC}"
kubectl delete -f dns/ --ignore-not-found=true
echo -e "${RED}✅ DNS tools removed${NC}"
echo ""

# Delete Plain YAML - Service Mesh
echo -e "${YELLOW}🕸️  Removing Service Mesh...${NC}"
kubectl delete -f service-mesh/ --ignore-not-found=true
echo -e "${RED}✅ Service Mesh removed${NC}"
echo ""

# Delete Plain YAML - eBPF
echo -e "${YELLOW}🔬 Removing eBPF tools...${NC}"
kubectl delete -f ebpf/ --ignore-not-found=true
echo -e "${RED}✅ eBPF tools removed${NC}"
echo ""

# Delete Plain YAML - K8s Core
echo -e "${YELLOW}⚙️  Removing K8s Core...${NC}"
kubectl delete -f k8s-core/ --ignore-not-found=true
echo -e "${RED}✅ K8s Core removed${NC}"
echo ""

# Delete Helm - Databases
echo -e "${YELLOW}💾 Removing Databases...${NC}"
helm uninstall redis-diag -n diagnostic-db --ignore-not-found 2>/dev/null || true
helm uninstall postgres-diag -n diagnostic-db --ignore-not-found 2>/dev/null || true
helm uninstall mariadb-diag -n diagnostic-db --ignore-not-found 2>/dev/null || true
echo -e "${RED}✅ Databases removed${NC}"
echo ""

# Delete Helm - Storage
echo -e "${YELLOW}📦 Removing Storage...${NC}"
helm uninstall minio-diag -n diagnostic-storage --ignore-not-found 2>/dev/null || true
echo -e "${RED}✅ Storage removed${NC}"
echo ""

# Delete Helm - Registry
echo -e "${YELLOW}🐳 Removing Registry...${NC}"
helm uninstall registry-diag -n diagnostic-registry --ignore-not-found 2>/dev/null || true
echo -e "${RED}✅ Registry removed${NC}"
echo ""

# Delete namespaces
echo -e "${YELLOW}📦 Removing namespaces...${NC}"
kubectl delete namespace diagnostic-web --ignore-not-found=true
kubectl delete namespace diagnostic-net --ignore-not-found=true
kubectl delete namespace diagnostic-db --ignore-not-found=true
kubectl delete namespace diagnostic-storage --ignore-not-found=true
kubectl delete namespace diagnostic-registry --ignore-not-found=true
kubectl delete namespace diagnostic-mesh --ignore-not-found=true
kubectl delete namespace diagnostic-ebpf --ignore-not-found=true
kubectl delete namespace diagnostic-core --ignore-not-found=true
echo -e "${RED}✅ Namespaces removed${NC}"
echo ""

echo -e "${RED}🎉 All diagnostic tools removed successfully!${NC}"
echo ""
echo "📊 To verify cleanup:"
echo "  kubectl get pods -A | grep diagnostic"
echo "  kubectl get ns | grep diagnostic"
echo "  helm list -A | grep diag"
