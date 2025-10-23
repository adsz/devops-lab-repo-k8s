output "backup_failure_alarm_arn" {
  description = "ARN of the Velero backup failure alarm"
  value       = aws_cloudwatch_metric_alarm.backup_failure_alarm.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.backup_dashboard.dashboard_name
}
