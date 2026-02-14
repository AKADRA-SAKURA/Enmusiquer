terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
    }
  }
}

variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "enabled" {
  type        = bool
  description = "Create Discord alerting resources when true."
  default     = false
}

variable "discord_webhook_url" {
  type        = string
  description = "Discord incoming webhook URL."
  default     = null
  sensitive   = true
}

variable "topic_name" {
  type        = string
  description = "SNS topic name override."
  default     = null
}

locals {
  sns_topic_name = var.topic_name != null ? var.topic_name : "${var.name_prefix}-alerts"
}

check "discord_webhook_when_enabled" {
  assert {
    condition     = !var.enabled || trimspace(coalesce(var.discord_webhook_url, "")) != ""
    error_message = "discord_webhook_url is required when enabled is true."
  }
}

resource "aws_sns_topic" "this" {
  count = var.enabled ? 1 : 0

  name = local.sns_topic_name
}

data "archive_file" "lambda_zip" {
  count = var.enabled ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/discord_alert.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  count = var.enabled ? 1 : 0

  name               = "${var.name_prefix}-discord-alert-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_logs" {
  count = var.enabled ? 1 : 0

  name   = "${var.name_prefix}-discord-alert-logs"
  role   = aws_iam_role.lambda[0].id
  policy = data.aws_iam_policy_document.lambda_logs.json
}

resource "aws_lambda_function" "discord_alert" {
  count = var.enabled ? 1 : 0

  function_name = "${var.name_prefix}-discord-alert"
  role          = aws_iam_role.lambda[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 10

  filename         = data.archive_file.lambda_zip[0].output_path
  source_code_hash = data.archive_file.lambda_zip[0].output_base64sha256

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }

  depends_on = [aws_iam_role_policy.lambda_logs]
}

resource "aws_lambda_permission" "allow_sns" {
  count = var.enabled ? 1 : 0

  statement_id  = "AllowExecutionFromSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_alert[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.this[0].arn
}

resource "aws_sns_topic_subscription" "lambda" {
  count = var.enabled ? 1 : 0

  topic_arn = aws_sns_topic.this[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_alert[0].arn

  depends_on = [aws_lambda_permission.allow_sns]
}

output "topic_arn" {
  value       = var.enabled ? aws_sns_topic.this[0].arn : null
  description = "SNS topic ARN used for Discord alerting."
}
