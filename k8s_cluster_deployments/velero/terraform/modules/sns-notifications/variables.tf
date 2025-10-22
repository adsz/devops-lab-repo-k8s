# Variables for SNS Notifications Module

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s-cluster"
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
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "telegram_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Telegram credentials"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ses_account_id" {
  description = "AWS account ID where SES is configured (aws2)"
  type        = string
  default     = ""
}

variable "jenkins_role_arn" {
  description = "ARN of the Jenkins IAM role"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "k8s-backup"
    Owner     = "devops-team"
  }
}
