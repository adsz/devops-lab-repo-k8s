# Outputs for S3 Backup Module

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.k8s_backup.bucket
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.k8s_backup.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.k8s_backup.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.k8s_backup.bucket_regional_domain_name
}

output "cloudwatch_alarm_arn" {
  description = "ARN of the CloudWatch alarm for bucket size monitoring"
  value       = aws_cloudwatch_metric_alarm.s3_backup_size.arn
}