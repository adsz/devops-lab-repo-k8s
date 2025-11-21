# 📝 Demo App: Simple Blog (Custom Multi-tier)

Własna aplikacja blog - kompletny target do testowania wszystkich narzędzi diagnostycznych.

---

## 📦 Architektura

```
                    ┌─────────────┐
                    │  Frontend   │ ← Nginx + HTML/JS
                    │ (NodePort   │   (http://node-ip:30080)
                    │   :30080)   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │     API     │ ← Python Flask REST
                    │ (NodePort   │   (http://node-ip:30050)
                    │   :30050)   │
                    └──────┬──────┘
                           │
       ┌───────────────────┴───────────────────┐
       │                                       │
┌──────▼──────┐                    ┌───────▼────────┐
│  PostgreSQL │                    │     Redis      │
│ (Port 5432) │                    │  (Port 6379)   │
└─────────────┘                    └────────────────┘
```

---

## 🎯 Komponenty (4 serwisy)

| # | Komponent | Technologia | Port | Funkcja |
|---|-----------|------------|------|---------|
| 1 | **Frontend** | Nginx + HTML/JS | 80 (NodePort 30080) | Web UI |
| 2 | **API** | Python Flask | 5000 (NodePort 30050) | REST API |
| 3 | **Database** | PostgreSQL | 5432 | Posts, comments |
| 4 | **Cache** | Redis | 6379 | API response cache |

---

## 📡 API Endpoints

### Health & Metrics
```
GET  /health              # Health check (database + redis)
GET  /ready               # Readiness probe
```

### Posts
```
GET    /api/posts              # List all posts (with Redis caching)
POST   /api/posts              # Create post
GET    /api/posts/{id}         # Get single post (increments views)
```

### Comments
```
GET    /api/posts/{id}/comments    # Get post comments
POST   /api/posts/{id}/comments    # Add comment to post
```

### Statistics
```
GET  /api/stats            # System statistics (posts, comments, views, cache keys)
```

---

## 🚀 Quick Start

### 1. Deploy aplikacji
```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments/demo-app-blog

# Deploy all components
./deploy.sh k8s

# Check status
kubectl get pods -n demo-blog
kubectl get svc -n demo-blog
```

### 2. Dostęp do aplikacji
```bash
# Frontend (NodePort)
http://192.168.0.190:30080

# API (NodePort)
http://192.168.0.190:30050

# Or use any worker node IP
```

### 3. Test API
```bash
# Health check
curl http://192.168.0.190:30050/health

# Get statistics
curl http://192.168.0.190:30050/api/stats

# Get posts
curl http://192.168.0.190:30050/api/posts

# Create post
curl -X POST http://192.168.0.190:30050/api/posts \
  -H 'Content-Type: application/json' \
  -d '{"title":"Test Post","content":"Hello from API","author":"DevOps"}'
```

---

## 🧪 Testowanie z diagnostic tools

Zobacz [`TESTING-GUIDE.md`](TESTING-GUIDE.md) dla szczegółowych przykładów.

**Quick test:**
```bash
# Deploy diagnostic tools
kubectl apply -f ../network-debug/curl.yaml

# Test frontend
kubectl exec curl -n diagnostic-net -- curl -s http://blog-frontend.demo-blog

# Test API
kubectl exec curl -n diagnostic-net -- curl -s http://blog-api.demo-blog:5000/health

# Test database connectivity
kubectl exec curl -n diagnostic-net -- nc -zv blog-db.demo-blog 5432

# Test Redis
kubectl exec curl -n diagnostic-net -- nc -zv blog-cache.demo-blog 6379
```

---

## 📊 Resource Requirements

**Minimalne:**
- CPU: 1 core
- RAM: 1.5 GB
- Nodes: 1-2 worker nodes

**Zalecane:**
- CPU: 2 cores
- RAM: 3 GB
- Nodes: 2+ worker nodes

---

## 🗄️ Database Schema

### Posts table
```sql
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    author VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    views INT DEFAULT 0,
    published BOOLEAN DEFAULT true
);
```

### Comments table
```sql
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    post_id INT REFERENCES posts(id),
    author VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```


---

## 🔧 Development

### Build Docker images (Harbor)
```bash
# Frontend
docker build -t harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-frontend:1.0 src/frontend/
docker push harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-frontend:1.0

# API
docker build -t harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-api:1.0 src/api/
docker push harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-api:1.0
```

### Local testing
```bash
# Run with docker-compose (optional)
docker-compose up

# Test API
curl http://localhost:5000/health

# Or deploy to K8s
./deploy.sh k8s
```

---

## 🧹 Cleanup

```bash
# Use cleanup script
./cleanup.sh k8s

# Or manually
kubectl delete namespace demo-blog
```

---

## 📁 Struktura plików

```
demo-app-blog/
├── README.md              # Quick start guide
├── docs/                  # Full documentation
│   ├── README.md          # Architecture & setup
│   ├── TESTING-GUIDE.md   # Testing with 22 tools
│   └── HARBOR-INTEGRATION.md
├── deploy.sh              # Deployment script
├── cleanup.sh             # Cleanup script
├── docker-compose.yml     # Local development (optional)
│
├── src/
│   ├── frontend/          # Nginx + HTML/CSS/JS
│   │   ├── index.html
│   │   ├── app.js
│   │   ├── styles.css
│   │   ├── nginx.conf
│   │   └── Dockerfile
│   │
│   └── api/               # Python Flask REST API
│       ├── app.py
│       ├── requirements.txt
│       └── Dockerfile
│
└── k8s/                   # Kubernetes manifests (Kustomize)
    ├── kustomization.yaml
    ├── namespace.yaml
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── api-deployment.yaml
    ├── api-service.yaml
    ├── api-configmap.yaml
    ├── database-statefulset.yaml
    ├── database-service.yaml
    ├── database-secret.yaml
    ├── cache-deployment.yaml
    └── cache-service.yaml
```

---

## 🎯 Use Cases

### 1. Web/API Testing
- Test frontend with curl, nginx diagnostic tools
- Test REST API endpoints
- Load testing with Apache Bench
- HTTP response validation

### 2. Database Testing
- PostgreSQL connectivity and queries
- Redis caching effectiveness
- Connection pool testing
- Data persistence validation

### 3. Network Testing
- Service-to-service communication
- DNS resolution (dnsutils)
- Port connectivity (netshoot, busybox)
- Network tracing and monitoring

### 4. Application Debugging
- Container logs analysis
- Health check validation
- Performance profiling
- Cache hit/miss ratio analysis

---

## 🔗 Comparison with Other Demos

| Feature | Blog App | Google Demo | Sock Shop |
|---------|----------|-------------|-----------|
| **Complexity** | Low | Medium-High | Medium |
| **Components** | 4 | 11 | 8-13 |
| **Databases** | PostgreSQL, Redis | Redis | MongoDB, MySQL |
| **API Type** | REST | gRPC | REST |
| **Registry** | Harbor | - | - |
| **Best for** | **Learning, Testing** | Production-like | E-commerce |

**Blog App advantages:**
- ✅ Simplest to understand (only 4 components)
- ✅ All 22 diagnostic tools applicable
- ✅ Complete CRUD operations
- ✅ Real-world patterns (caching, health checks)
- ✅ Harbor registry integration
- ✅ Easy to deploy and test

---

**Status:** ✅ Deployed and Running
**Cluster:** k8s-master-1 + 2 workers (v1.29.15)
**Namespace:** demo-blog
**Registry:** Harbor (k8s-diagnostic-demos project)
**Access:**
- Frontend: http://192.168.0.190:30080
- API: http://192.168.0.190:30050
