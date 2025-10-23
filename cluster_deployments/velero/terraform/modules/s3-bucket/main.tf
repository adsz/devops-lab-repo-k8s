# S3 Backup Module for Kubernetes Enterprise Backup Solution
# Manages S3 bucket for Velero backups with enterprise-grade configuration

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# S3 Bucket for Kubernetes backups
resource "aws_s3_bucket" "k8s_backup" {
  bucket = var.bucket_name

  tags = merge(var.common_tags, {
    Name        = var.bucket_name
    Purpose     = "Kubernetes cluster backups"
    BackupTool  = "Velero"
    Environment = var.environment
  })
}

# Bucket versioning disabled to save costs (using timestamp naming instead)
resource "aws_s3_bucket_versioning" "k8s_backup_versioning" {
  bucket = aws_s3_bucket.k8s_backup.id
  versioning_configuration {
    status = "Disabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "k8s_backup_encryption" {
  bucket = aws_s3_bucket.k8s_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "k8s_backup_pab" {
  bucket = aws_s3_bucket.k8s_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "k8s_backup_lifecycle" {
  bucket = aws_s3_bucket.k8s_backup.id

  rule {
    id     = "backup_retention"
    status = "Enabled"
    
    filter {
      prefix = ""
    }

    # Move to cheaper storage after 30 days (minimum for STANDARD_IA)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after 60 days
    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    # Delete backups older than retention period (must be greater than all transitions)
    expiration {
      days = 90
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket policy for Velero access
resource "aws_s3_bucket_policy" "k8s_backup_policy" {
  bucket = aws_s3_bucket.k8s_backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VeleroBackupAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.velero_iam_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          aws_s3_bucket.k8s_backup.arn,
          "${aws_s3_bucket.k8s_backup.arn}/*"
        ]
      },
      {
        Sid    = "JenkinsBackupAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.jenkins_iam_role_arn
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.k8s_backup.arn,
          "${aws_s3_bucket.k8s_backup.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch metrics for bucket monitoring
resource "aws_cloudwatch_metric_alarm" "s3_backup_size" {
  alarm_name          = "${var.bucket_name}-size-monitor"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = "86400"
  statistic           = "Average"
  threshold           = var.backup_size_threshold_gb * 1024 * 1024 * 1024
  alarm_description   = "This metric monitors S3 bucket size for backup storage"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    BucketName  = aws_s3_bucket.k8s_backup.bucket
    StorageType = "StandardStorage"
  }

  tags = var.common_tags
}