variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

output "db_identifier" {
  value       = "${var.name_prefix}-postgres"
  description = "Placeholder RDS identifier."
}
