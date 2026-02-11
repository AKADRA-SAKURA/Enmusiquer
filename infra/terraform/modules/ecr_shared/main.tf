variable "repository_prefix" {
  type        = string
  description = "Prefix for ECR repositories."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

output "repository_namespace" {
  value       = "${var.repository_prefix}-${var.environment}"
  description = "Placeholder ECR repository namespace."
}
