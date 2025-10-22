# SNS Notifications Module for Kubernetes Backup Alerts
# Creates SNS topics and subscriptions for backup notifications

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# SNS Topic for backup notifications
resource "aws_sns_topic" "backup_notifications" {
  name = "${var.cluster_name}-backup-notifications"

  tags = merge(var.common_tags, {
    Name    = "${var.cluster_name}-backup-notifications"
    Purpose = "Kubernetes backup notifications"
  })
}

# SNS Topic for critical backup alerts
resource "aws_sns_topic" "backup_alerts" {
  name = "${var.cluster_name}-backup-alerts"

  tags = merge(var.common_tags, {
    Name    = "${var.cluster_name}-backup-alerts"
    Purpose = "Critical backup failure alerts"
  })
}

# Email subscription for backup notifications
resource "aws_sns_topic_subscription" "backup_notifications_email" {
  count     = length(var.notification_emails)
  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_emails[count.index]
}

# Email subscription for critical alerts
resource "aws_sns_topic_subscription" "backup_alerts_email" {
  count     = length(var.alert_emails)
  topic_arn = aws_sns_topic.backup_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

# Slack webhook subscription (if webhook URL provided)
resource "aws_sns_topic_subscription" "backup_notifications_slack" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# Lambda function for Telegram notifications
resource "aws_lambda_function" "telegram_notifier" {
  count         = var.telegram_bot_token != "" ? 1 : 0
  filename      = data.archive_file.telegram_lambda_zip[0].output_path
  function_name = "${var.cluster_name}-telegram-notifier"
  role          = aws_iam_role.telegram_lambda_role[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30
  depends_on    = [aws_cloudwatch_log_group.telegram_lambda]

  source_code_hash = data.archive_file.telegram_lambda_zip[0].output_base64sha256

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN = var.telegram_bot_token
      TELEGRAM_CHAT_ID   = var.telegram_chat_id
    }
  }

  tags = var.common_tags
}

# Dedicated log group for the Telegram notifier (ensures dashboard widget works even before first invocation)
resource "aws_cloudwatch_log_group" "telegram_lambda" {
  count             = var.telegram_bot_token != "" ? 1 : 0
  name              = "/aws/lambda/${var.cluster_name}-telegram-notifier"
  retention_in_days = 30

  tags = var.common_tags
}

# Lambda function code for Telegram
data "archive_file" "telegram_lambda_zip" {
  count       = var.telegram_bot_token != "" ? 1 : 0
  type        = "zip"
  output_path = "/tmp/telegram_lambda.zip"
  
  source {
    content = templatefile("${path.module}/lambda/telegram_notifier.py", {
      bot_token = var.telegram_bot_token
      chat_id   = var.telegram_chat_id
    })
    filename = "lambda_function.py"
  }
}

# IAM role for Telegram Lambda
resource "aws_iam_role" "telegram_lambda_role" {
  count = var.telegram_bot_token != "" ? 1 : 0
  name  = "${var.cluster_name}-telegram-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "telegram_lambda_basic" {
  count      = var.telegram_bot_token != "" ? 1 : 0
  role       = aws_iam_role.telegram_lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SNS subscription for Telegram Lambda
resource "aws_sns_topic_subscription" "backup_notifications_telegram" {
  count     = var.telegram_bot_token != "" ? 1 : 0
  topic_arn = aws_sns_topic.backup_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.telegram_notifier[0].arn
}

# Lambda permission for SNS
resource "aws_lambda_permission" "allow_sns_telegram" {
  count         = var.telegram_bot_token != "" ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telegram_notifier[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.backup_notifications.arn
}

# SNS topic policy for cross-account SES integration
resource "aws_sns_topic_policy" "backup_notifications_policy" {
  arn = aws_sns_topic.backup_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowJenkinsPublish"
        Effect = "Allow"
        Principal = {
          AWS = var.jenkins_role_arn
        }
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.backup_notifications.arn
      }
    ]
  })
}
