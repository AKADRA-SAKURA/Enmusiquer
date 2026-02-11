variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "root_domain" {
  type        = string
  description = "Root domain for auth callbacks."
}

output "user_pool_name" {
  value       = "${var.name_prefix}-users"
  description = "Placeholder Cognito user pool name."
}
