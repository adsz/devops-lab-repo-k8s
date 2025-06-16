helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Default service type is NodePort — access via node IP + NodePort.
# If you’re on a cloud, set service type to LoadBalancer:

# helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --set controller.service.type=LoadBalancer

# Check deployment
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx


