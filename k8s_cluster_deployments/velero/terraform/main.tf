# Main Terraform configuration for K8s backup infrastructure
# Production environment - aws5 (default) profile

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }

  # Remote state backend (configure as needed)
  # backend "s3" {
  #   bucket = "aws5-terraform-state"
  #   key    = "k8s-backup/terraform.tfstate"
  #   region = "eu-central-1"
  # }
}

# AWS Provider configuration (uses default profile = aws5)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = "production"
      Project     = "k8s-backup"
      Owner       = "devops-team"
    }
  }
}

# Kubernetes provider configuration
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Local values for common configurations
locals {
  cluster_name = "k8s-production"
  common_tags = {
    ManagedBy   = "terraform"
    Environment = "production"
    Project     = "k8s-backup"
    Owner       = "devops-team"
    CreatedBy   = "terraform-k8s-backup"
  }
}

# S3 backup module
module "s3_backup" {
  source = "./modules/s3-bucket"

  bucket_name              = var.s3_bucket_name
  environment              = "production"
  backup_retention_days    = 30
  backup_size_threshold_gb = 100
  velero_iam_role_arn      = module.iam_backup.velero_role_arn
  jenkins_iam_role_arn     = module.iam_backup.jenkins_role_arn
  sns_topic_arn            = module.sns_notifications.backup_notifications_topic_arn
  common_tags              = local.common_tags
}

# IAM backup module
module "iam_backup" {
  source = "./modules/irsa-role"

  cluster_name               = local.cluster_name
  s3_bucket_arn              = module.s3_backup.bucket_arn
  sns_topic_arn              = module.sns_notifications.backup_notifications_topic_arn
  aws_region                 = var.aws_region
  create_k8s_service_account = false
  common_tags                = local.common_tags
}

# SNS notifications module
module "sns_notifications" {
  source = "./modules/sns-notifications"

  cluster_name        = local.cluster_name
  notification_emails = var.notification_emails
  alert_emails        = var.alert_emails
  slack_webhook_url   = var.slack_webhook_url
  telegram_bot_token  = var.telegram_bot_token
  telegram_chat_id    = var.telegram_chat_id
  jenkins_role_arn    = module.iam_backup.jenkins_role_arn
  common_tags         = local.common_tags
}

# CloudWatch alarms for backup monitoring
module "cloudwatch_monitoring" {
  source = "./modules/cloudwatch-monitoring"

  cluster_name            = local.cluster_name
  s3_bucket_name          = var.s3_bucket_name
  aws_region              = var.aws_region
  backup_alerts_topic_arn = module.sns_notifications.backup_alerts_topic_arn
  common_tags             = local.common_tags
}
