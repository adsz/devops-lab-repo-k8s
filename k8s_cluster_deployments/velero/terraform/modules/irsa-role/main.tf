# IAM Backup Module for Kubernetes Enterprise Backup Solution
# Creates IAM roles and policies for Velero and Jenkins backup operations

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Velero IAM Role for S3 access
resource "aws_iam_role" "velero_backup_role" {
  name = "${var.cluster_name}-velero-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.cluster_name}-velero-backup-role"
    Purpose = "Velero backup operations"
  })
}

# Velero IAM Policy for S3 and Volume Snapshot operations
resource "aws_iam_policy" "velero_backup_policy" {
  name = "${var.cluster_name}-velero-backup-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VeleroS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Sid    = "VeleroS3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "s3:GetBucketLocation",
          "s3:ListBucketVersions",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = var.s3_bucket_arn
      },
      {
        Sid    = "VeleroEBSSnapshotAccess"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      },
      {
        Sid    = "VeleroKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Attach policy to Velero role
resource "aws_iam_role_policy_attachment" "velero_backup_policy" {
  role       = aws_iam_role.velero_backup_role.name
  policy_arn = aws_iam_policy.velero_backup_policy.arn
}

# Jenkins IAM Role for backup automation
resource "aws_iam_role" "jenkins_backup_role" {
  name = "${var.cluster_name}-jenkins-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.cluster_name}-jenkins-backup-role"
    Purpose = "Jenkins backup automation"
  })
}

# Jenkins IAM Policy for S3 access and SNS notifications
resource "aws_iam_policy" "jenkins_backup_policy" {
  name = "${var.cluster_name}-jenkins-backup-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "JenkinsS3BackupAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Sid    = "JenkinsSNSNotifications"
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:CreateTopic",
          "sns:Subscribe",
          "sns:Unsubscribe"
        ]
        Resource = var.sns_topic_arn
      },
      {
        Sid    = "JenkinsCloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "JenkinsVeleroAccess"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = aws_iam_role.velero_backup_role.arn
      }
    ]
  })

  tags = var.common_tags
}

# Attach policy to Jenkins role
resource "aws_iam_role_policy_attachment" "jenkins_backup_policy" {
  role       = aws_iam_role.jenkins_backup_role.name
  policy_arn = aws_iam_policy.jenkins_backup_policy.arn
}

# Instance profile for Jenkins EC2 instance
resource "aws_iam_instance_profile" "jenkins_backup_profile" {
  name = "${var.cluster_name}-jenkins-backup-profile"
  role = aws_iam_role.jenkins_backup_role.name

  tags = var.common_tags
}

# Service account for Velero in Kubernetes cluster
resource "kubernetes_service_account" "velero" {
  count = var.create_k8s_service_account ? 1 : 0
  
  metadata {
    name      = "velero"
    namespace = "velero"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.velero_backup_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "velero"
      "app.kubernetes.io/component"  = "backup"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [kubernetes_namespace.velero]
}

# Velero namespace
resource "kubernetes_namespace" "velero" {
  count = var.create_k8s_service_account ? 1 : 0
  
  metadata {
    name = "velero"
    labels = {
      "app.kubernetes.io/name"       = "velero"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# IAM OIDC provider data (for EKS clusters)
data "aws_eks_cluster" "cluster" {
  count = var.eks_cluster_name != "" ? 1 : 0
  name  = var.eks_cluster_name
}

data "aws_iam_openid_connect_provider" "cluster" {
  count = var.eks_cluster_name != "" ? 1 : 0
  url   = data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer
}