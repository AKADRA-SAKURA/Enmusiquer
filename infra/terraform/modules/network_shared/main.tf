variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

output "vpc_name" {
  value       = "${var.name_prefix}-vpc"
  description = "Placeholder VPC name."
}
