variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

output "bucket_name" {
  value       = "${var.name_prefix}-assets"
  description = "Placeholder app S3 bucket name."
}
