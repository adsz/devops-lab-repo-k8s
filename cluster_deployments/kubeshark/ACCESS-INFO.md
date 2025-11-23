# Kubeshark External Access - Quick Reference

## ✅ External Access (Configured and Working)

### Direct IP Access (Recommended - No Configuration Needed)
```
http://192.168.0.210
```
**Simply open this URL in your browser** to access Kubeshark dashboard from any machine on the network. No additional configuration required!

### Hostname Access (Optional)
```
http://kubeshark.local
```
Requires adding the following entry to your `/etc/hosts` file:
```
192.168.0.210   kubeshark.local
```

**Both methods are fully functional and working!**

## Ingress Details

**Status:** Active and working
**Ingress Class:** nginx
**IP Address:** 192.168.0.210
**Namespace:** kubeshark
**Service:** kubeshark-front:80

## Verification

Test access from command line:
```bash
curl -I http://192.168.0.210
# Expected: HTTP/1.1 200 OK

curl -I http://192.168.0.210 -H "Host: kubeshark.local"
# Expected: HTTP/1.1 200 OK
```

## Alternative Access Methods

### Port Forward (Local Only)
```bash
kubectl port-forward -n kubeshark svc/kubeshark-front 8899:80
# Then access: http://localhost:8899
```

## Network Configuration

- **Ingress Controller:** nginx-ingress-controller
- **Load Balancer IP:** 192.168.0.210
- **Ports:** 80 (HTTP), 443 (HTTPS - if configured)

## Security Notes

- Currently accessible via HTTP (no TLS)
- No authentication configured (default)
- Accessible from any machine on 192.168.0.x network
- Consider adding ingress authentication for production use

## Adding TLS/HTTPS

To enable HTTPS with Let's Encrypt:
1. Edit `ingress.yaml`
2. Add cert-manager annotation
3. Configure TLS section with your domain
4. Apply changes: `kubectl apply -f ingress.yaml`

See README.md for detailed TLS configuration.
