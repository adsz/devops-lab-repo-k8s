# 🧪 Testing Guide - Diagnostic Tools vs Sock Shop

Przewodnik testowania narzędzi diagnostycznych na aplikacji Sock Shop.

---

## 🎯 Setup

### 1. Deploy Sock Shop
```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments/demo-app-sockshop
kubectl create namespace sock-shop
kubectl apply -f kubernetes-manifests.yaml
kubectl wait --for=condition=Ready pod --all -n sock-shop --timeout=300s
```

### 2. Deploy diagnostic tools
```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments
kubectl create namespace diagnostic-net
kubectl apply -f network-debug/
kubectl apply -f dns/
```

---

## 📦 Category 1: Web/HTTP Testing

### Test 1: Frontend (Node.js)
```bash
# Basic HTTP test
kubectl exec curl -n diagnostic-net -- curl -I http://front-end.sock-shop:80

# Get catalogue
kubectl exec curl -n diagnostic-net -- curl http://front-end.sock-shop/catalogue

# Get specific item
kubectl exec curl -n diagnostic-net -- curl http://front-end.sock-shop/catalogue/03fef6ac-1896-4ce8-bd69-b798f85c6e0b
```

### Test 2: Catalogue Service (Go)
```bash
# List all products
kubectl exec curl -n diagnostic-net -- curl http://catalogue.sock-shop/catalogue

# Count products
kubectl exec curl -n diagnostic-net -- curl http://catalogue.sock-shop/catalogue/size

# Get tags
kubectl exec curl -n diagnostic-net -- curl http://catalogue.sock-shop/tags
```

### Test 3: Cart Service (Java)
```bash
# Get cart (requires customer ID)
kubectl exec curl -n diagnostic-net -- curl http://carts.sock-shop/carts/test-user

# Add to cart
kubectl exec curl -n diagnostic-net -- curl -X POST \
  http://carts.sock-shop/carts/test-user/items \
  -H 'Content-Type: application/json' \
  -d '{"itemId":"03fef6ac-1896-4ce8-bd69-b798f85c6e0b","quantity":1}'
```

### Test 4: Orders Service (Java)
```bash
# Get orders
kubectl exec curl -n diagnostic-net -- curl http://orders.sock-shop/orders

# Get specific order
kubectl exec curl -n diagnostic-net -- curl http://orders.sock-shop/orders/test-user
```

### Test 5: User Service (Go)
```bash
# Get users
kubectl exec curl -n diagnostic-net -- curl http://user.sock-shop/customers

# Register user
kubectl exec curl -n diagnostic-net -- curl -X POST \
  http://user.sock-shop/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"testuser","password":"testpass","email":"test@example.com"}'

# Login
kubectl exec curl -n diagnostic-net -- curl -X GET \
  http://user.sock-shop/login \
  -u testuser:testpass
```

---

## 📦 Category 2: Database Testing

### Test MongoDB (Catalogue, Carts, User)
```bash
# Deploy netshoot for mongo client
kubectl apply -f ../network-debug/netshoot.yaml
kubectl exec -it netshoot -n diagnostic-net -- bash

# Inside netshoot:
apk add mongodb-tools

# Connect to catalogue DB
mongo --host catalogue-db.sock-shop:27017

# In mongo shell:
show dbs
use socksdb
show collections
db.sock.find().limit(5)
exit

# Connect to carts DB
mongo --host carts-db.sock-shop:27017
show dbs
use data
show collections
db.cart.find()
exit

# Connect to user DB
mongo --host user-db.sock-shop:27017
show dbs
use users
show collections
db.customers.find()
exit

exit  # Exit netshoot
```

### Test MySQL (Orders)
```bash
# Inside netshoot:
apk add mysql-client

# Connect to orders DB
mysql -h orders-db.sock-shop -u root -p
# Password: fake_password (check manifests)

# In MySQL:
SHOW DATABASES;
USE socksdb;
SHOW TABLES;
SELECT * FROM orders LIMIT 5;
SELECT * FROM customer_order LIMIT 5;
EXIT;

exit  # Exit netshoot
```

### Test with Database Helm Charts
```bash
# Deploy PostgreSQL for comparison
kubectl create namespace diagnostic-db
helm install postgres-test ../databases/postgres -n diagnostic-db

# Test PostgreSQL
kubectl exec netshoot -n diagnostic-net -- psql \
  -h postgres-test-postgres-diagnostic.diagnostic-db \
  -U postgres -d testdb

# Deploy Redis
helm install redis-test ../databases/redis -n diagnostic-db

# Test Redis
kubectl exec netshoot -n diagnostic-net -- redis-cli \
  -h redis-test-redis-diagnostic.diagnostic-db PING
```

---

## 📦 Category 3: Message Queue Testing

### Test RabbitMQ
```bash
# Check RabbitMQ availability
kubectl exec curl -n diagnostic-net -- nc -zv rabbitmq.sock-shop 5672

# RabbitMQ Management API (if enabled)
kubectl exec curl -n diagnostic-net -- curl http://rabbitmq.sock-shop:15672/api/overview

# Inside netshoot:
kubectl exec -it netshoot -n diagnostic-net -- bash

# Install amqp-tools
apk add --no-cache py3-pip
pip3 install pika

# Test connection
python3 << 'EOF'
import pika
connection = pika.BlockingConnection(
    pika.ConnectionParameters('rabbitmq.sock-shop')
)
channel = connection.channel()
print("✅ RabbitMQ connection successful")
connection.close()
EOF

exit
```

---

## 📦 Category 4: DNS Testing

### Test all services DNS
```bash
# Basic DNS lookup
for svc in front-end catalogue carts orders user payment shipping queue-master; do
  echo "=== $svc ==="
  kubectl exec dnsutils -n diagnostic-net -- nslookup $svc.sock-shop
done

# Database DNS
for db in catalogue-db carts-db orders-db user-db rabbitmq; do
  echo "=== $db ==="
  kubectl exec dnsutils -n diagnostic-net -- nslookup $db.sock-shop
done

# Dig detailed
kubectl exec dnsutils -n diagnostic-net -- dig front-end.sock-shop.svc.cluster.local

# Reverse DNS
FRONT_END_IP=$(kubectl get svc front-end -n sock-shop -o jsonpath='{.spec.clusterIP}')
kubectl exec dnsutils -n diagnostic-net -- dig -x $FRONT_END_IP
```

---

## 📦 Category 5: Network Testing

### Connectivity Matrix
```bash
#!/bin/bash
# Test connectivity between all services

SERVICES=(
  "front-end:80"
  "catalogue:80"
  "carts:80"
  "orders:80"
  "user:80"
  "payment:80"
  "shipping:80"
  "queue-master:80"
  "catalogue-db:27017"
  "carts-db:27017"
  "orders-db:3306"
  "user-db:27017"
  "rabbitmq:5672"
)

echo "Testing connectivity to all Sock Shop services..."
for svc_port in "${SERVICES[@]}"; do
  svc=$(echo $svc_port | cut -d: -f1)
  port=$(echo $svc_port | cut -d: -f2)
  printf "%-20s %-6s " "$svc" ":$port"
  kubectl exec curl -n diagnostic-net -- timeout 5 nc -zv $svc.sock-shop $port 2>&1 | grep -q succeeded && echo "✅ OK" || echo "❌ FAIL"
done
```

### Network Performance
```bash
# Ping test
for svc in front-end catalogue carts orders user; do
  echo "=== Ping $svc ==="
  kubectl exec busybox -n diagnostic-net -- ping -c 3 $svc.sock-shop
done

# Bandwidth test (if iperf available)
kubectl exec netshoot -n diagnostic-net -- iperf3 -c front-end.sock-shop -t 10
```

---

## 🔍 Advanced Testing Scenarios

### Scenario 1: Complete E2E Flow
```bash
#!/bin/bash
# Test complete user flow: browse → add to cart → checkout

NS="sock-shop"
USER="testuser-$(date +%s)"

# 1. Register user
echo "1. Registering user..."
kubectl exec curl -n diagnostic-net -- curl -X POST \
  http://user.$NS/register \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USER\",\"password\":\"pass\",\"email\":\"$USER@test.com\"}"

# 2. Browse catalogue
echo "2. Browsing catalogue..."
ITEMS=$(kubectl exec curl -n diagnostic-net -- curl -s http://catalogue.$NS/catalogue)
ITEM_ID=$(echo $ITEMS | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Selected item: $ITEM_ID"

# 3. Add to cart
echo "3. Adding to cart..."
kubectl exec curl -n diagnostic-net -- curl -X POST \
  http://carts.$NS/carts/$USER/items \
  -H 'Content-Type: application/json' \
  -d "{\"itemId\":\"$ITEM_ID\",\"quantity\":1}"

# 4. View cart
echo "4. Viewing cart..."
kubectl exec curl -n diagnostic-net -- curl http://carts.$NS/carts/$USER

# 5. Create order
echo "5. Creating order..."
kubectl exec curl -n diagnostic-net -- curl -X POST \
  http://orders.$NS/orders \
  -H 'Content-Type: application/json' \
  -d "{\"customer\":\"$USER\",\"address\":\"test\",\"card\":\"test\",\"items\":\"$ITEM_ID\"}"

echo "✅ E2E flow complete!"
```

### Scenario 2: Database Load Testing
```bash
# Load test catalogue queries
kubectl exec curl -n diagnostic-net -- sh -c '
  for i in $(seq 1 100); do
    curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" \
      http://catalogue.sock-shop/catalogue
  done
' | awk '{sum+=$2; count++} END {print "Avg:", sum/count, "s"}'

# Concurrent requests
kubectl exec curl -n diagnostic-net -- sh -c '
  for i in $(seq 1 10); do
    curl -s http://catalogue.sock-shop/catalogue &
  done
  wait
'
```

### Scenario 3: Failure Testing
```bash
# Test resilience - kill pods and check recovery

# Kill catalogue pod
kubectl delete pod -n sock-shop -l name=catalogue

# Test if service still works (should recover)
sleep 10
kubectl exec curl -n diagnostic-net -- curl http://catalogue.sock-shop/catalogue

# Check pod recreation
kubectl get pods -n sock-shop -l name=catalogue
```

---

## 📊 Complete Service Test Matrix

| Service | HTTP | MongoDB | MySQL | RabbitMQ | DNS |
|---------|------|---------|-------|----------|-----|
| front-end | ✅ | - | - | - | ✅ |
| catalogue | ✅ | ✅ | - | - | ✅ |
| carts | ✅ | ✅ | - | - | ✅ |
| orders | ✅ | - | ✅ | ✅ | ✅ |
| user | ✅ | ✅ | - | - | ✅ |
| payment | ✅ | - | - | - | ✅ |
| shipping | ✅ | - | - | ✅ | ✅ |
| queue-master | ✅ | - | - | ✅ | ✅ |

---

## 🎯 Key Differences from Google Demo

### Sock Shop advantages for testing:
1. **Multiple database types** - MongoDB, MySQL (vs only Redis)
2. **Message queue** - RabbitMQ (vs none)
3. **REST API** - Easy to test with curl (vs gRPC)
4. **Persistent storage** - Tests PVC/storage classes
5. **Mixed languages** - Go, Java, Node.js

### Best testing scenarios:
- ✅ **Database connectivity** - Multiple DB types
- ✅ **REST API testing** - All services HTTP
- ✅ **Message queues** - RabbitMQ integration
- ✅ **Storage testing** - Persistent volumes
- ✅ **Multi-language debugging** - Various stacks

---

## 📝 Testing Checklist

### Basic Connectivity
- [ ] All services respond to HTTP requests
- [ ] All databases accessible
- [ ] RabbitMQ connection works
- [ ] DNS resolution correct

### Advanced Testing
- [ ] E2E user flow works
- [ ] Cart persistence works
- [ ] Order creation successful
- [ ] Database queries performant
- [ ] Message queue processing

### Diagnostic Tools
- [ ] curl - HTTP requests work
- [ ] netshoot - DB connections work
- [ ] dnsutils - DNS lookups correct
- [ ] busybox - Ping tests pass

---

**Happy Testing!** 🧦
