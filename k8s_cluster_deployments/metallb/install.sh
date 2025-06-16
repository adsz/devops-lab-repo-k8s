kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml

kubectl apply -f ipaddresspool.yaml
kubectl apply -f l2advertisement.yaml

# Zmień Service dla swojego demo-nginx z ClusterIP na LoadBalancer. Przykład pliku test-service.yaml
# apiVersion: v1
# kind: Service
# metadata:
#   name: exampleService
#   namespace: foo
# spec:
#   type: LoadBalancer
#   selector:
#     app: demo-nginx
#   ports:
#     - protocol: TCP
#       port: 80
#       targetPort: 80


# kubectl apply -f test-service.yaml

# Sprawdź adres:
# kubectl get svc -n foo

