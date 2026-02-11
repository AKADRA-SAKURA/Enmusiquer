variable "root_domain" {
  type        = string
  description = "Root domain managed by Route53."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

output "hosted_zone_name" {
  value       = var.root_domain
  description = "Placeholder hosted zone name."
}
