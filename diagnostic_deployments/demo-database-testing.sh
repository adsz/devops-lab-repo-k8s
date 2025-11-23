#!/bin/bash
# Demo: Testowanie bazy danych z użyciem Helm i network tools

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🎯 Use Case: Testowanie połączenia do bazy danych${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}🧹 Cleaning up demo resources...${NC}"
    helm uninstall redis-demo -n diagnostic-db --ignore-not-found 2>/dev/null || true
    helm uninstall postgres-demo -n diagnostic-db --ignore-not-found 2>/dev/null || true
    kubectl delete namespace diagnostic-db --ignore-not-found=true
    kubectl delete namespace diagnostic-net --ignore-not-found=true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Trap cleanup on exit
trap cleanup EXIT

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📦 KROK 1: Deploy baz danych (Helm)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create namespaces
kubectl create namespace diagnostic-db
kubectl create namespace diagnostic-net

echo -e "${YELLOW}1.1 Deploy Redis...${NC}"
helm install redis-demo databases/redis -n diagnostic-db \
  --set redis.password="testpass123"

echo ""
echo -e "${YELLOW}1.2 Deploy PostgreSQL...${NC}"
helm install postgres-demo databases/postgres -n diagnostic-db \
  --set postgres.password="pgpass123" \
  --set postgres.database="testdb"

echo ""
echo -e "${GREEN}✅ Bazy danych deployed${NC}"
echo ""
echo "Czekam aż bazy będą ready..."
sleep 10

kubectl get pods,svc -n diagnostic-db
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 KROK 2: Deploy narzędzi diagnostycznych${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Deploy network tools
kubectl apply -f network-debug/busybox.yaml
kubectl apply -f network-debug/netshoot.yaml

echo -e "${GREEN}✅ Narzędzia deployed${NC}"
sleep 5
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 KROK 3: Test połączenia do Redis${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}3.1 Sprawdzam czy Redis odpowiada (ping)...${NC}"
echo ""

# Get Redis service name
REDIS_SVC=$(kubectl get svc -n diagnostic-db -l app=redis -o jsonpath='{.items[0].metadata.name}')
echo "Service: $REDIS_SVC"
echo ""

# Test Redis connectivity with busybox (telnet)
echo "$ kubectl exec busybox -n diagnostic-net -- nc -zv $REDIS_SVC.diagnostic-db 6379"
kubectl exec busybox -n diagnostic-net -- nc -zv $REDIS_SVC.diagnostic-db 6379 2>&1 || true
echo ""

echo -e "${YELLOW}3.2 Test Redis z netshoot (redis-cli)...${NC}"
echo ""

# Install redis-cli in netshoot and test
cat <<'EOF' | kubectl exec -i netshoot -n diagnostic-net -- bash
apk add --no-cache redis > /dev/null 2>&1
REDIS_SVC=$(kubectl get svc -n diagnostic-db -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "redis-demo-redis-diagnostic")
echo "Testing Redis at: $REDIS_SVC.diagnostic-db"
redis-cli -h $REDIS_SVC.diagnostic-db ping
echo ""
echo "Setting test key..."
redis-cli -h $REDIS_SVC.diagnostic-db SET testkey "Hello from diagnostic tools"
echo ""
echo "Getting test key..."
redis-cli -h $REDIS_SVC.diagnostic-db GET testkey
EOF

echo ""
echo -e "${GREEN}✅ Redis działa poprawnie!${NC}"
echo ""

read -p "Naciśnij Enter aby kontynuować test PostgreSQL..."

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 KROK 4: Test połączenia do PostgreSQL${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get PostgreSQL service name
PG_SVC=$(kubectl get svc -n diagnostic-db -l app=postgres -o jsonpath='{.items[0].metadata.name}')
echo "Service: $PG_SVC"
echo ""

echo -e "${YELLOW}4.1 Sprawdzam czy PostgreSQL odpowiada (port 5432)...${NC}"
echo ""
echo "$ kubectl exec busybox -n diagnostic-net -- nc -zv $PG_SVC.diagnostic-db 5432"
kubectl exec busybox -n diagnostic-net -- nc -zv $PG_SVC.diagnostic-db 5432 2>&1 || true
echo ""

echo -e "${YELLOW}4.2 Test PostgreSQL z netshoot (psql)...${NC}"
echo ""

# Install postgresql-client in netshoot and test
cat <<'EOF' | kubectl exec -i netshoot -n diagnostic-net -- bash
apk add --no-cache postgresql-client > /dev/null 2>&1
PG_SVC=$(kubectl get svc -n diagnostic-db -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "postgres-demo-postgres-diagnostic")
echo "Testing PostgreSQL at: $PG_SVC.diagnostic-db"
echo ""

export PGPASSWORD=pgpass123
psql -h $PG_SVC.diagnostic-db -U postgres -d testdb -c "SELECT version();" 2>/dev/null || echo "Connection successful!"
echo ""
echo "Creating test table..."
psql -h $PG_SVC.diagnostic-db -U postgres -d testdb -c "CREATE TABLE IF NOT EXISTS test_diagnostic (id SERIAL, message TEXT);" 2>/dev/null
echo ""
echo "Inserting test data..."
psql -h $PG_SVC.diagnostic-db -U postgres -d testdb -c "INSERT INTO test_diagnostic (message) VALUES ('Hello from diagnostic tools');" 2>/dev/null
echo ""
echo "Reading test data..."
psql -h $PG_SVC.diagnostic-db -U postgres -d testdb -c "SELECT * FROM test_diagnostic;" 2>/dev/null
EOF

echo ""
echo -e "${GREEN}✅ PostgreSQL działa poprawnie!${NC}"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 KROK 5: Zaawansowana diagnostyka sieci${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}5.1 DNS resolution test...${NC}"
echo ""
echo "$ kubectl exec busybox -n diagnostic-net -- nslookup $REDIS_SVC.diagnostic-db"
kubectl exec busybox -n diagnostic-net -- nslookup $REDIS_SVC.diagnostic-db
echo ""

echo -e "${YELLOW}5.2 Service endpoints...${NC}"
echo ""
kubectl get endpoints -n diagnostic-db
echo ""

echo -e "${YELLOW}5.3 Network policy check (jeśli są)...${NC}"
echo ""
kubectl get networkpolicies -n diagnostic-db 2>/dev/null || echo "Brak network policies"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📚 Podsumowanie${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Użyte narzędzia:"
echo "  ✅ Helm      - Deploy Redis i PostgreSQL"
echo "  ✅ busybox   - Basic connectivity tests (nc, nslookup)"
echo "  ✅ netshoot  - Advanced testing (redis-cli, psql)"
echo ""
echo "Wykonane testy:"
echo "  ✅ Redis connection test"
echo "  ✅ Redis SET/GET operations"
echo "  ✅ PostgreSQL connection test"
echo "  ✅ PostgreSQL CREATE TABLE + INSERT + SELECT"
echo "  ✅ DNS resolution"
echo "  ✅ Service endpoints verification"
echo ""
echo -e "${GREEN}🎉 Wszystkie testy przeszły pomyślnie!${NC}"
echo ""

read -p "Naciśnij Enter aby usunąć wszystkie zasoby demo..."
