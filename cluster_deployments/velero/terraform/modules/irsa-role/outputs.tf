# Outputs for IAM Backup Module

output "velero_role_arn" {
  description = "ARN of the Velero IAM role"
  value       = aws_iam_role.velero_backup_role.arn
}

output "velero_role_name" {
  description = "Name of the Velero IAM role"
  value       = aws_iam_role.velero_backup_role.name
}

output "jenkins_role_arn" {
  description = "ARN of the Jenkins backup IAM role"
  value       = aws_iam_role.jenkins_backup_role.arn
}

output "jenkins_role_name" {
  description = "Name of the Jenkins backup IAM role"
  value       = aws_iam_role.jenkins_backup_role.name
}

output "jenkins_instance_profile_name" {
  description = "Name of the Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins_backup_profile.name
}

output "jenkins_instance_profile_arn" {
  description = "ARN of the Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins_backup_profile.arn
}

output "velero_service_account_name" {
  description = "Name of the Velero Kubernetes service account"
  value       = var.create_k8s_service_account ? kubernetes_service_account.velero[0].metadata[0].name : null
}

output "velero_namespace" {
  description = "Velero namespace name"
  value       = var.create_k8s_service_account ? kubernetes_namespace.velero[0].metadata[0].name : "velero"
}