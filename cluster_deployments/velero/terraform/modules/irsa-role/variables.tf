# Variables for IAM Backup Module

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s-cluster"
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for backups"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for EKS cluster"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  type        = string
  default     = ""
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster (if using EKS)"
  type        = string
  default     = ""
}

variable "create_k8s_service_account" {
  description = "Whether to create Kubernetes service account for Velero"
  type        = bool
  default     = true
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