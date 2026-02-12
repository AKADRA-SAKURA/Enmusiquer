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
  description = "Create monitoring resources when true."
  default     = false
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name."
  default     = null
}

variable "ecs_service_name" {
  type        = string
  description = "ECS service name."
  default     = null
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix for CloudWatch metrics."
  default     = null
}

variable "db_identifier" {
  type        = string
  description = "RDS DB instance identifier."
  default     = null
}

variable "alarm_actions" {
  type        = list(string)
  description = "Alarm action ARNs (for example SNS topic)."
  default     = []
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  count = var.enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_description   = "ECS CPU utilization is high."
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  count = var.enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_description   = "ALB target 5xx count is high."
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_description   = "RDS CPU utilization is high."
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }
}

output "alarm_namespace" {
  value       = "${var.name_prefix}-alarms"
  description = "Monitoring alarm namespace label."
}

output "alarm_names" {
  value = compact([
    try(aws_cloudwatch_metric_alarm.ecs_cpu_high[0].alarm_name, null),
    try(aws_cloudwatch_metric_alarm.alb_5xx_high[0].alarm_name, null),
    try(aws_cloudwatch_metric_alarm.rds_cpu_high[0].alarm_name, null),
  ])
  description = "Created CloudWatch alarm names."
}
