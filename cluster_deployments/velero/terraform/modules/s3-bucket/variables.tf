# Variables for S3 Backup Module

variable "bucket_name" {
  description = "Name of the S3 bucket for Kubernetes backups"
  type        = string
  default     = "aws5-k8s-backup"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "backup_size_threshold_gb" {
  description = "CloudWatch alarm threshold for bucket size in GB"
  type        = number
  default     = 100
}

variable "velero_iam_role_arn" {
  description = "IAM role ARN for Velero service account"
  type        = string
}

variable "jenkins_iam_role_arn" {
  description = "IAM role ARN for Jenkins backup automation"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
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