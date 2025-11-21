# Blog App - Demo Application for K8s Diagnostics

Simple multi-tier blog application deployed to Kubernetes cluster with Harbor registry integration.

## Quick Start

```bash
# Deploy to Kubernetes
./deploy.sh k8s

# Access application
Frontend: http://<node-ip>:30080
API:      http://<node-ip>:30050
```

## Components

- **Frontend**: Nginx + HTML/CSS/JS
- **API**: Python Flask REST API
- **Database**: PostgreSQL
- **Cache**: Redis

## Documentation

Complete documentation available in [`docs/`](docs/) folder:

- **[docs/README.md](docs/README.md)** - Full architecture and setup guide
- **[docs/TESTING-GUIDE.md](docs/TESTING-GUIDE.md)** - Testing with 22 diagnostic tools
- **[docs/HARBOR-INTEGRATION.md](docs/HARBOR-INTEGRATION.md)** - Harbor registry integration

## Structure

```
demo-app-blog/
├── src/           # Application source code
├── k8s/           # Kubernetes manifests
├── docs/          # Documentation
├── deploy.sh      # Deployment script
└── cleanup.sh     # Cleanup script
```

## Status

✅ Deployed to `demo-blog` namespace
✅ Images in Harbor: `harbor.devops-lab.cloud/k8s-diagnostic-demos/`
✅ All pods running and healthy
