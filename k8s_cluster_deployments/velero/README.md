# Velero Deployment Guide

This directory contains the manifests required to deploy Velero with an AWS S3 backend. Secrets stay local and are ignored by git.

## Prerequisites
- `helm` v3 and `kubectl` configured for the target cluster
- Velero CLI installed locally (optional for verification)
- AWS credentials stored in `cloud-credentials.secret.yaml` or `cloud-credentials.conf` (gitignored)

## Deployment Steps
1. Create namespace and apply credentials secret (adjust values as needed):
   ```bash
   kubectl create namespace velero
   kubectl apply -f cloud-credentials.secret.yaml
   ```
2. Install or upgrade Velero via Helm:
   ```bash
   helm upgrade --install velero vmware-tanzu/velero \
     -n velero --create-namespace \
     -f values.yaml --reset-values
   ```
3. Configure storage locations and schedules:
   ```bash
   kubectl apply -f backup-storage-location.yaml
   kubectl apply -f volume-snapshot-location.yaml
   kubectl apply -f backup-schedule.yaml
   ```
4. Verify installation:
   ```bash
   kubectl get deployment velero -n velero
   velero backup get
   ```

## AWS Infrastructure (Terraform)
Terraform configuration lives in `terraform/`. It provisions the S3 bucket, IAM roles (including the IRSA role referenced in `values.yaml`), and SNS topics.

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Set `create_k8s_service_account = false` (already configured) so Terraform manages only AWS resources while Helm owns the Velero namespace and service account.
If you previously applied an older version that created the namespace/service account, run:

```bash
terraform state rm module.iam_backup.kubernetes_namespace.velero
terraform state rm module.iam_backup.kubernetes_service_account.velero
```

before the next `terraform apply` to avoid Terraform attempting to delete them.

Optional: if you maintain an S3 Storage Lens group that targets the `velero/` and `etcd-full-backup/` prefixes (for example `k8s-backups`), set the group name in `storage_lens_group` inside `terraform.tfvars`. The CloudWatch dashboard will then display both the bucket-wide metrics and prefix-specific size/object counts. Leave the value blank to omit the prefix widget.

For Telegram notifications, create a Secrets Manager entry once (outside Terraform), for example:

```bash
aws secretsmanager create-secret \
  --name k8s-production-telegram-notifier \
  --secret-string '{"TELEGRAM_TOKEN":"<token>","TELEGRAM_CHAT_ID":"<chat_id>"}'
```

Then set `telegram_secret_arn = "arn:aws:secretsmanager:...:secret:k8s-production-telegram-notifier"` in `terraform.tfvars` (or export `TF_VAR_telegram_secret_arn`). Terraform will provision the Lambda, log group `/aws/lambda/<cluster>-telegram-notifier`, and wire the CloudWatch widget automatically. Without the secret ARN the notifier stays disabled and the widget is hidden, preventing "log group not found" errors.

## Cleanup
```bash
helm uninstall velero -n velero
kubectl delete namespace velero
```
