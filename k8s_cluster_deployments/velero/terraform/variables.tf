# Variables for production environment

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-central-1"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for backups"
  type        = string
  default     = "aws5-k8s-backup"
}

variable "notification_emails" {
  description = "List of email addresses for backup notifications"
  type        = list(string)
  default     = ["jenkins@devops-lab.cloud", "admin@devops-lab.cloud"]
}

variable "alert_emails" {
  description = "List of email addresses for critical alerts"
  type        = list(string)
  default     = ["admin@devops-lab.cloud"]
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications (stored in secrets)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token for notifications (stored in secrets)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_chat_id" {
  description = "Telegram chat ID for notifications"
  type        = string
  default     = ""
}

variable "storage_lens_group" {
  description = "Optional Storage Lens group name covering Velero/etcd prefixes"
  type        = string
  default     = ""
}
