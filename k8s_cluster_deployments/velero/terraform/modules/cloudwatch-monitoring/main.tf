# CloudWatch monitoring module for Velero backups

resource "aws_cloudwatch_metric_alarm" "backup_failure_alarm" {
  alarm_name          = "${var.cluster_name}-backup-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BackupFailures"
  namespace           = "Velero"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors Velero backup failures"
  alarm_actions       = [var.backup_alerts_topic_arn]

  dimensions = {
    BackupStorageLocation = "default"
  }

  tags = var.common_tags
}

locals {
  prefix_metrics = var.storage_lens_group == "" ? [] : [
    ["AWS/S3", "BucketSizeBytes", "StorageLensGroup", var.storage_lens_group, "StorageType", "StandardStorage"],
    ["AWS/S3", "NumberOfObjects", "StorageLensGroup", var.storage_lens_group, "StorageType", "AllStorageTypes"]
  ]
}

locals {
  log_widget = var.notification_log_group == "" ? [] : [
    {
      type   = "log"
      x      = 0
      y      = 6
      width  = 24
      height = 6
      properties = {
        query  = "SOURCE '${var.notification_log_group}'\n| fields @timestamp, @message\n| sort @timestamp desc\n| limit 20"
        region = var.aws_region
        title  = "Backup Notifications Log"
      }
    }
  ]
}

resource "aws_cloudwatch_dashboard" "backup_dashboard" {
  dashboard_name = "${var.cluster_name}-backup-monitoring"

  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/S3", "BucketSizeBytes", "BucketName", var.s3_bucket_name, "StorageType", "StandardStorage"],
              [".", "NumberOfObjects", "BucketName", var.s3_bucket_name, "StorageType", "AllStorageTypes"]
            ]
            period = 86400
            stat   = "Average"
            region = var.aws_region
            title  = "S3 Backup Bucket Metrics"
          }
        }
      ],
      local.prefix_metrics == [] ? [] : [
        {
          type   = "metric"
          x      = 12
          y      = 0
          width  = 12
          height = 6
          properties = {
            metrics = local.prefix_metrics
            period  = 86400
            stat    = "Average"
            region  = var.aws_region
            title   = "Velero / Etcd Prefix Metrics"
            yAxis  = {
              left = {
                label = "Bytes"
              }
            }
          }
        }
      ],
      local.log_widget
    )
  })
}
