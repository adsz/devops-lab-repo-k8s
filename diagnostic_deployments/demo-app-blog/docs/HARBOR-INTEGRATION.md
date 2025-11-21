# Harbor Integration - Blog App

## Summary

Blog App został zintegrowany z Harbor Registry zgodnie z best practices dla enterprise Kubernetes.

## Harbor Configuration

**Registry URL:** `https://harbor.devops-lab.cloud`
**Project:** `k8s-diagnostic-demos`
**Access:** Public project (no imagePullSecrets required)

## Images

```
harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-api:1.0
harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-frontend:1.0
```

## Deployment Status

✅ **All components running:**
- Database (PostgreSQL): `blog-db-0` - Running
- Cache (Redis): `blog-cache-xxx` - Running
- API (Flask): `blog-api-xxx` (2 replicas) - Running
- Frontend (Nginx): `blog-frontend-xxx` (2 replicas) - Running

✅ **Health Checks:**
```json
{
  "status": "healthy",
  "checks": {
    "database": "ok",
    "redis": "ok"
  }
}
```

✅ **Access:**
- Frontend: `http://<any-node-ip>:30080`
- API: `http://blog-api.demo-blog:5000` (internal)

## Build & Deploy Workflow

### 1. Build Images Locally

```bash
cd /repos/devops-lab-new/k8s-local/diagnostic_deployments/demo-app-blog

# Build with Harbor tags
docker build -t harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-api:1.0 ./src/api
docker build -t harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-frontend:1.0 ./src/frontend
```

### 2. Push to Harbor

```bash
# Login (if not already logged in)
docker login harbor.devops-lab.cloud -u admin

# Push images
docker push harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-api:1.0
docker push harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-frontend:1.0
```

### 3. Deploy to Kubernetes

```bash
# Deploy using Kustomize
kubectl apply -k ./k8s/

# Wait for rollout
kubectl rollout status deployment/blog-api -n demo-blog
kubectl rollout status deployment/blog-frontend -n demo-blog
```

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -n demo-blog

# Test API health
kubectl run test-curl --image=curlimages/curl:latest -n demo-blog --rm -it -- \
  curl http://blog-api:5000/health

# Access frontend
curl http://192.168.0.190:30080/
```

## CI/CD Integration

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any

    environment {
        HARBOR_URL = 'harbor.devops-lab.cloud'
        PROJECT = 'k8s-diagnostic-demos'
        VERSION = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Build') {
            steps {
                sh '''
                    docker build -t ${HARBOR_URL}/${PROJECT}/blog-api:${VERSION} ./src/api
                    docker build -t ${HARBOR_URL}/${PROJECT}/blog-frontend:${VERSION} ./src/frontend
                '''
            }
        }

        stage('Push to Harbor') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-creds',
                    usernameVariable: 'USER',
                    passwordVariable: 'PASS'
                )]) {
                    sh '''
                        echo $PASS | docker login ${HARBOR_URL} -u $USER --password-stdin
                        docker push ${HARBOR_URL}/${PROJECT}/blog-api:${VERSION}
                        docker push ${HARBOR_URL}/${PROJECT}/blog-frontend:${VERSION}
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    kubectl set image deployment/blog-api \
                      api=${HARBOR_URL}/${PROJECT}/blog-api:${VERSION} -n demo-blog
                    kubectl set image deployment/blog-frontend \
                      nginx=${HARBOR_URL}/${PROJECT}/blog-frontend:${VERSION} -n demo-blog
                '''
            }
        }
    }
}
```

## Harbor Features Enabled

✅ **Image Scanning:** Trivy scanner configured
✅ **Public Project:** No authentication required for pulls
✅ **Webhook Support:** Ready for CI/CD integration
✅ **Replication:** Can replicate to other registries
✅ **Retention Policy:** Can be configured for image cleanup

## Security Features

### Image Scanning

Harbor automatically scans images with Trivy on push:

```bash
# View scan results via Harbor UI or API
curl -u admin:admin123 \
  "https://harbor.devops-lab.cloud/api/v2.0/projects/k8s-diagnostic-demos/repositories/blog-api/artifacts/1.0/scan"
```

### RBAC

Project access can be controlled:
- Admin: Full access
- Developer: Push/pull images
- Guest: Pull only

## Troubleshooting

### Issue: Image Pull Errors

```bash
# Check if nodes can reach Harbor
kubectl run test-harbor --image=harbor.devops-lab.cloud/k8s-diagnostic-demos/blog-api:1.0 --rm -it

# For private projects, create imagePullSecret:
kubectl create secret docker-registry harbor-creds \
  --docker-server=harbor.devops-lab.cloud \
  --docker-username=admin \
  --docker-password=admin123 \
  -n demo-blog
```

### Issue: 403 Forbidden in Nginx

Fixed by setting proper file permissions in Dockerfile:

```dockerfile
COPY --chmod=644 index.html /usr/share/nginx/html/
```

## Best Practices Applied

✅ **Semantic Versioning:** Using version tags (1.0, 1.1, etc.)
✅ **Immutable Tags:** Each build gets a unique version
✅ **Public Project:** For demo/test applications
✅ **HTTPS Only:** Secure registry communication
✅ **Health Checks:** All containers have liveness/readiness probes
✅ **Resource Limits:** CPU and memory constraints defined

## Next Steps

1. **Set up automated CI/CD** - Jenkins/GitHub Actions to build and push on commit
2. **Configure image retention** - Keep last N versions, delete old images
3. **Enable webhook notifications** - Notify Slack/Teams on image push
4. **Set up replication** - Mirror images to DR registry
5. **Implement signed images** - Use Notary for image signing

## References

- Harbor Project: https://goharbor.io/
- Harbor API Docs: https://harbor.devops-lab.cloud/devcenter-api-2.0
- Blog App Repo: `/repos/devops-lab-new/k8s-local/diagnostic_deployments/demo-app-blog`
