# Blog App - Testing Guide with Diagnostic Tools

This guide demonstrates how to use the "Golden 22" diagnostic tools to test, debug, and monitor the Blog App.

## Quick Start

### Deploy the Blog App

```bash
# Deploy to Kubernetes
./deploy.sh k8s

# OR deploy with Docker Compose
./deploy.sh docker
```

### Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n demo-blog

# Expected output:
# blog-api-xxx        2/2     Running
# blog-cache-xxx      1/1     Running
# blog-db-0           1/1     Running
# blog-frontend-xxx   2/2     Running
```

---

## Testing Scenarios with Diagnostic Tools

### 1. Web/HTTP Testing Tools

#### Test Frontend Availability (nginx)

```bash
# Deploy nginx tester
kubectl apply -f ../web-http/overlays/dev

# Test frontend from nginx pod
kubectl exec -it deployment/nginx-dev -n diagnostic-web -- \
  curl -v http://blog-frontend.demo-blog.svc.cluster.local

# Expected: HTML content with "Simple Blog"
```

#### Test API Endpoints (curl)

```bash
# Deploy curl pod
kubectl apply -f ../network-debug/curl.yaml

# Test API health check
kubectl exec -it curl -n diagnostic-net -- \
  curl -s http://blog-api.demo-blog:5000/health | jq .

# Test get posts
kubectl exec -it curl -n diagnostic-net -- \
  curl -s http://blog-api.demo-blog:5000/api/posts | jq .

# Create a test post
kubectl exec -it curl -n diagnostic-net -- \
  curl -X POST http://blog-api.demo-blog:5000/api/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Post","author":"Admin","content":"Testing from curl!"}'

# Get statistics
kubectl exec -it curl -n diagnostic-net -- \
  curl -s http://blog-api.demo-blog:5000/api/stats | jq .
```

#### Test with HTTPBin Features (httpbin)

```bash
# Deploy httpbin
kubectl apply -f ../web-http/overlays/dev

# Test API headers
kubectl exec -it deployment/httpbin-dev -n diagnostic-web -- \
  curl -s http://blog-api.demo-blog:5000/health | python -m json.tool
```

#### Load Testing (Apache Bench via httpd)

```bash
# Deploy httpd
kubectl apply -f ../web-http/overlays/dev

# Run load test
kubectl exec -it deployment/httpd-dev -n diagnostic-web -- \
  ab -n 1000 -c 10 http://blog-api.demo-blog:5000/health

# Expected: Shows requests/sec, response times
```

---

### 2. Network Debugging Tools

#### DNS Resolution Testing (dnsutils)

```bash
# Deploy dnsutils
kubectl apply -f ../dns/dnsutils.yaml

# Resolve blog services
kubectl exec -it dnsutils -n diagnostic-dns -- \
  nslookup blog-api.demo-blog.svc.cluster.local

kubectl exec -it dnsutils -n diagnostic-dns -- \
  nslookup blog-db.demo-blog.svc.cluster.local

kubectl exec -it dnsutils -n diagnostic-dns -- \
  dig blog-frontend.demo-blog.svc.cluster.local
```

#### Network Connectivity Testing (netshoot)

```bash
# Deploy netshoot
kubectl apply -f ../network-debug/netshoot.yaml

# Test connectivity to all services
kubectl exec -it netshoot -n diagnostic-net -- \
  nc -zv blog-api.demo-blog 5000

kubectl exec -it netshoot -n diagnostic-net -- \
  nc -zv blog-db.demo-blog 5432

kubectl exec -it netshoot -n diagnostic-net -- \
  nc -zv blog-cache.demo-blog 6379

# Trace route to API
kubectl exec -it netshoot -n diagnostic-net -- \
  traceroute blog-api.demo-blog

# Check DNS resolution path
kubectl exec -it netshoot -n diagnostic-net -- \
  drill blog-api.demo-blog.svc.cluster.local
```

#### Network Monitoring (network-multitool)

```bash
# Deploy network-multitool
kubectl apply -f ../network-debug/network-multitool.yaml

# Monitor traffic to API
kubectl exec -it network-multitool -n diagnostic-net -- \
  tcpdump -i any -n host blog-api.demo-blog

# Check open ports
kubectl exec -it network-multitool -n diagnostic-net -- \
  nmap -p 5000 blog-api.demo-blog
```

#### Basic Connectivity (busybox)

```bash
# Deploy busybox
kubectl apply -f ../network-debug/busybox.yaml

# Ping test
kubectl exec -it busybox -n diagnostic-net -- \
  ping -c 5 blog-api.demo-blog

# Wget test
kubectl exec -it busybox -n diagnostic-net -- \
  wget -O- http://blog-api.demo-blog:5000/health
```

---

### 3. Database Testing

#### PostgreSQL Direct Access

```bash
# Install postgres client in a diagnostic pod
kubectl run -it --rm psql-client --image=postgres:16-alpine -n demo-blog -- \
  psql -h blog-db -U blog -d blogdb

# Inside psql shell:
\dt                          # List tables
SELECT * FROM posts;         # View all posts
SELECT * FROM comments;      # View all comments
SELECT COUNT(*) FROM posts;  # Count posts

# Or run queries directly:
kubectl exec -it blog-db-0 -n demo-blog -- \
  psql -U blog -d blogdb -c "SELECT id, title, author, views FROM posts;"
```

#### Redis Cache Inspection

```bash
# Connect to Redis
kubectl exec -it deployment/blog-cache -n demo-blog -- redis-cli

# Inside redis-cli:
KEYS *              # List all keys
GET posts:all       # Get cached posts
TTL posts:all       # Check TTL
DBSIZE              # Database size
INFO memory         # Memory usage

# Or run commands directly:
kubectl exec -it deployment/blog-cache -n demo-blog -- \
  redis-cli KEYS '*'
```

---

### 4. Application Monitoring Scenarios

#### Scenario: New Post Creation Flow

```bash
# 1. Create a post via API
kubectl exec -it curl -n diagnostic-net -- \
  curl -X POST http://blog-api.demo-blog:5000/api/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"Monitoring Test","author":"DevOps","content":"Testing the full stack!"}'

# 2. Verify in database
kubectl exec -it blog-db-0 -n demo-blog -- \
  psql -U blog -d blogdb -c "SELECT * FROM posts WHERE title='Monitoring Test';"

# 3. Check cache was cleared
kubectl exec -it deployment/blog-cache -n demo-blog -- \
  redis-cli KEYS '*'

# 4. Fetch posts (should rebuild cache)
kubectl exec -it curl -n diagnostic-net -- \
  curl -s http://blog-api.demo-blog:5000/api/posts

# 5. Verify cache was populated
kubectl exec -it deployment/blog-cache -n demo-blog -- \
  redis-cli GET posts:all
```

#### Scenario: High Load Testing

```bash
# 1. Monitor API logs
kubectl logs -f deployment/blog-api -n demo-blog &

# 2. Run load test
kubectl exec -it deployment/httpd-dev -n diagnostic-web -- \
  ab -n 10000 -c 50 http://blog-api.demo-blog:5000/api/posts

# 3. Check cache hit rate
kubectl exec -it deployment/blog-cache -n demo-blog -- \
  redis-cli INFO stats | grep keyspace

# 4. Check database connections
kubectl exec -it blog-db-0 -n demo-blog -- \
  psql -U blog -d blogdb -c "SELECT count(*) FROM pg_stat_activity;"
```

#### Scenario: Troubleshooting Connection Issues

```bash
# 1. Check API can reach database
kubectl exec -it deployment/blog-api -n demo-blog -- \
  nc -zv blog-db 5432

# 2. Check API can reach cache
kubectl exec -it deployment/blog-api -n demo-blog -- \
  nc -zv blog-cache 6379

# 3. Check health endpoints
kubectl exec -it curl -n diagnostic-net -- \
  curl -v http://blog-api.demo-blog:5000/health

# 4. Verify DNS resolution
kubectl exec -it dnsutils -n diagnostic-dns -- \
  nslookup blog-db.demo-blog.svc.cluster.local

# 5. Network trace
kubectl exec -it netshoot -n diagnostic-net -- \
  traceroute blog-db.demo-blog
```

---

### 5. Performance Analysis

#### API Response Time Testing

```bash
# Test API latency
kubectl exec -it curl -n diagnostic-net -- sh -c '
  for i in {1..10}; do
    time curl -s http://blog-api.demo-blog:5000/api/stats > /dev/null
  done
'
```

#### Cache Performance

```bash
# Clear cache
kubectl exec -it deployment/blog-cache -n demo-blog -- \
  redis-cli FLUSHALL

# First request (cache miss)
kubectl exec -it curl -n diagnostic-net -- sh -c \
  'time curl -s http://blog-api.demo-blog:5000/api/posts > /dev/null'

# Second request (cache hit - should be faster)
kubectl exec -it curl -n diagnostic-net -- sh -c \
  'time curl -s http://blog-api.demo-blog:5000/api/posts > /dev/null'
```

#### Database Query Performance

```bash
# Check slow queries
kubectl exec -it blog-db-0 -n demo-blog -- \
  psql -U blog -d blogdb -c "SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# Monitor active queries
kubectl exec -it blog-db-0 -n demo-blog -- \
  psql -U blog -d blogdb -c "SELECT pid, usename, state, query FROM pg_stat_activity WHERE state != 'idle';"
```

---

### 6. Security Testing

#### Check for Open Ports

```bash
kubectl exec -it network-multitool -n diagnostic-net -- \
  nmap -p 1-65535 blog-api.demo-blog
```

#### SSL/TLS Testing (if configured)

```bash
kubectl exec -it curl -n diagnostic-net -- \
  curl -vI https://blog-frontend.demo-blog
```

---

### 7. Data Validation

#### Verify Post Count Consistency

```bash
# Get count from API
API_COUNT=$(kubectl exec -it curl -n diagnostic-net -- \
  curl -s http://blog-api.demo-blog:5000/api/stats | jq -r '.posts')

# Get count from database
DB_COUNT=$(kubectl exec -it blog-db-0 -n demo-blog -- \
  psql -U blog -d blogdb -t -c "SELECT COUNT(*) FROM posts;" | tr -d ' ')

echo "API reports: $API_COUNT posts"
echo "DB contains: $DB_COUNT posts"

# Should match!
```

---

## Complete Test Suite Script

Here's a comprehensive test script combining multiple tools:

```bash
#!/bin/bash

echo "=== Blog App Diagnostic Test Suite ==="
echo ""

# 1. Connectivity Tests
echo "1️⃣  Testing connectivity..."
kubectl exec -it netshoot -n diagnostic-net -- \
  nc -zv blog-api.demo-blog 5000 && echo "✅ API reachable" || echo "❌ API unreachable"

kubectl exec -it netshoot -n diagnostic-net -- \
  nc -zv blog-db.demo-blog 5432 && echo "✅ DB reachable" || echo "❌ DB unreachable"

kubectl exec -it netshoot -n diagnostic-net -- \
  nc -zv blog-cache.demo-blog 6379 && echo "✅ Cache reachable" || echo "❌ Cache unreachable"

echo ""

# 2. DNS Tests
echo "2️⃣  Testing DNS resolution..."
kubectl exec -it dnsutils -n diagnostic-dns -- \
  nslookup blog-api.demo-blog.svc.cluster.local > /dev/null && echo "✅ API DNS OK"

echo ""

# 3. Health Checks
echo "3️⃣  Checking health endpoints..."
HEALTH=$(kubectl exec -it curl -n diagnostic-net -- \
  curl -s http://blog-api.demo-blog:5000/health | jq -r '.status')
echo "API Health: $HEALTH"

echo ""

# 4. Database Tests
echo "4️⃣  Testing database..."
kubectl exec -it blog-db-0 -n demo-blog -- \
  psql -U blog -d blogdb -c "SELECT COUNT(*) FROM posts;" && echo "✅ DB query OK"

echo ""

# 5. Cache Tests
echo "5️⃣  Testing cache..."
kubectl exec -it deployment/blog-cache -n demo-blog -- \
  redis-cli PING && echo "✅ Cache responding"

echo ""

# 6. API Functionality Tests
echo "6️⃣  Testing API endpoints..."
kubectl exec -it curl -n diagnostic-net -- \
  curl -s http://blog-api.demo-blog:5000/api/stats | jq . && echo "✅ Stats endpoint OK"

echo ""

# 7. Load Test
echo "7️⃣  Running load test..."
kubectl exec -it deployment/httpd-dev -n diagnostic-web -- \
  ab -n 100 -c 10 http://blog-api.demo-blog:5000/health | grep "Requests per second"

echo ""
echo "=== Test Suite Complete ==="
```

---

## Cleanup

```bash
# Remove Blog App
./cleanup.sh k8s

# Remove diagnostic tools
kubectl delete namespace diagnostic-web
kubectl delete namespace diagnostic-net
kubectl delete namespace diagnostic-dns
```

---

## Troubleshooting Common Issues

### Issue: API can't connect to database

```bash
# Check if database is ready
kubectl get pods -n demo-blog

# Check database logs
kubectl logs -f blog-db-0 -n demo-blog

# Verify database secret
kubectl get secret blog-db-secret -n demo-blog -o yaml

# Test connection from API pod
kubectl exec -it deployment/blog-api -n demo-blog -- \
  nc -zv blog-db 5432
```

### Issue: Cache not working

```bash
# Check Redis logs
kubectl logs -f deployment/blog-cache -n demo-blog

# Test Redis from API pod
kubectl exec -it deployment/blog-api -n demo-blog -- \
  nc -zv blog-cache 6379

# Check cache keys
kubectl exec -it deployment/blog-cache -n demo-blog -- \
  redis-cli KEYS '*'
```

### Issue: Frontend can't reach API

```bash
# Check frontend logs
kubectl logs -f deployment/blog-frontend -n demo-blog

# Test API from frontend pod
kubectl exec -it deployment/blog-frontend -n demo-blog -- \
  curl -v http://blog-api:5000/health

# Check service endpoints
kubectl get endpoints -n demo-blog
```

---

## Monitoring Recommendations

1. **Use Prometheus + Grafana** from the diagnostic tools to monitor:
   - API response times
   - Database query performance
   - Cache hit rates
   - Error rates

2. **Set up alerts** for:
   - API health check failures
   - Database connection errors
   - High response times
   - Cache connection issues

3. **Regular checks**:
   - Daily database backup verification
   - Weekly performance baseline tests
   - Monthly security scans

---

This testing guide demonstrates how the "Golden 22" diagnostic tools can be used to thoroughly test, monitor, and debug a real-world application stack in Kubernetes.
