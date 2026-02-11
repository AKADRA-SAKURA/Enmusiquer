variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

output "distribution_comment" {
  value       = "${var.name_prefix}-cdn"
  description = "Placeholder CloudFront distribution label."
}
