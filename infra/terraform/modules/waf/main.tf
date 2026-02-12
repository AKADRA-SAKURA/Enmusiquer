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
  description = "Create WAF resources when true."
  default     = false
}

variable "resource_arn" {
  type        = string
  description = "Regional resource ARN to associate WAF with (for example ALB ARN)."
  default     = null
}

variable "rate_limit" {
  type        = number
  description = "Rate-based rule limit per 5 minutes."
  default     = 2000
}

resource "aws_wafv2_web_acl" "this" {
  count = var.enabled ? 1 : 0

  name  = "${var.name_prefix}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.enabled ? 1 : 0

  resource_arn = var.resource_arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}

output "web_acl_name" {
  value       = var.enabled ? aws_wafv2_web_acl.this[0].name : null
  description = "WAF web ACL name."
}

output "web_acl_arn" {
  value       = var.enabled ? aws_wafv2_web_acl.this[0].arn : null
  description = "WAF web ACL ARN."
}
