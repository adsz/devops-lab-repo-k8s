# ✅ Validated Images - "Złota 22"

All 22 images have been tested and validated in Kubernetes cluster.

## 📦 Complete List

### Web/HTTP Testing (8 images)
1. ✅ `nginx:alpine` - Nginx web server
2. ✅ `httpd:alpine` - Apache HTTP server
3. ✅ `traefik/whoami` - Request info display
4. ✅ `gcr.io/google-samples/hello-app:1.0` - Google hello world
5. ✅ `kennethreitz/httpbin` - HTTP request testing
6. ✅ `ealen/echo-server` - Echo HTTP server
7. ✅ `k8s.gcr.io/echoserver:1.10` - Kubernetes echo server
8. ✅ `hashicorp/http-echo:latest` - HTTP echo (replacement for kuard)

### Network/Debug Tools (5 images)
9. ✅ `busybox:latest` - Basic networking tools
10. ✅ `curlimages/curl:latest` - HTTP client
11. ✅ `nicolaka/netshoot:latest` - Advanced network debug
12. ✅ `praqma/network-multitool:latest` - Multi-purpose network tool
13. ✅ `alpine:latest` - Lightweight base

### DNS Debugging (1 image)
14. ✅ `tutum/dnsutils:latest` - DNS tools (dig, nslookup, host)

### Databases (3 images)
15. ✅ `redis:7-alpine` - Redis cache/database
16. ✅ `postgres:16-alpine` - PostgreSQL database
17. ✅ `mariadb:11` - MariaDB/MySQL database (standard, not alpine)

### Storage (1 image)
18. ✅ `minio/minio:latest` - S3-compatible object storage

### Registry (1 image)
19. ✅ `registry:2` - Docker Registry v2

### Service Mesh (1 image)
20. ✅ `envoyproxy/envoy:distroless-v1.31` - Envoy proxy

### eBPF (1 image)
21. ✅ `quay.io/iovisor/bpftrace:latest` - eBPF tracing (from Quay.io)

### K8s Core (1 image)
22. ✅ `k8s.gcr.io/pause:3.9` - Kubernetes pause container

---

## 🔧 Image Replacements

### Original vs Validated

| Original Plan | Validated Image | Reason |
|--------------|-----------------|--------|
| `gcr.io/kuar-demo/kuard-amd64:blue` | `hashicorp/http-echo:latest` | GCR.io 412 error |
| `mariadb:11-alpine` | `mariadb:11` | Alpine variant not available |
| `iovisor/bpftrace:latest` | `quay.io/iovisor/bpftrace:latest` | Moved to Quay.io |

---

## ✅ Validation Status

**Date:** 2025-11-21
**Cluster:** k8s-master-1 (v1.29.15)
**Method:** Group deployment testing
**Result:** ALL 22 IMAGES WORKING

See `TEST-VALIDATION.md` for detailed test results.
