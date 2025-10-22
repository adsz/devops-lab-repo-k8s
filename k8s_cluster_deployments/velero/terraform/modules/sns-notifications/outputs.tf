# Outputs for SNS Notifications Module

output "backup_notifications_topic_arn" {
  description = "ARN of the backup notifications SNS topic"
  value       = aws_sns_topic.backup_notifications.arn
}

output "backup_alerts_topic_arn" {
  description = "ARN of the backup alerts SNS topic"
  value       = aws_sns_topic.backup_alerts.arn
}

output "backup_notifications_topic_name" {
  description = "Name of the backup notifications SNS topic"
  value       = aws_sns_topic.backup_notifications.name
}

output "backup_alerts_topic_name" {
  description = "Name of the backup alerts SNS topic"
  value       = aws_sns_topic.backup_alerts.name
}

output "telegram_lambda_function_name" {
  description = "Name of the Telegram notification Lambda function"
  value       = var.telegram_bot_token != "" ? aws_lambda_function.telegram_notifier[0].function_name : null
}

output "telegram_lambda_function_arn" {
  description = "ARN of the Telegram notification Lambda function"
  value       = var.telegram_bot_token != "" ? aws_lambda_function.telegram_notifier[0].arn : null
}

output "telegram_lambda_log_group" {
  description = "CloudWatch log group name used by the Telegram notifier"
  value       = var.telegram_bot_token != "" ? aws_cloudwatch_log_group.telegram_lambda[0].name : null
}
