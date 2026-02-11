variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

output "web_acl_name" {
  value       = "${var.name_prefix}-waf"
  description = "Placeholder WAF web ACL name."
}
