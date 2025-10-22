variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket monitored on the dashboard"
  type        = string
}

variable "aws_region" {
  description = "AWS region for CloudWatch queries"
  type        = string
}

variable "backup_alerts_topic_arn" {
  description = "SNS topic ARN for backup failure alerts"
  type        = string
}

variable "velero_filter_id" {
  description = "Optional CloudWatch S3 Storage Lens filter ID for Velero backups prefix"
  type        = string
  default     = ""
}

variable "etcd_filter_id" {
  description = "Optional CloudWatch S3 Storage Lens filter ID for etcd backups prefix"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to CloudWatch resources"
  type        = map(string)
  default     = {}
}
