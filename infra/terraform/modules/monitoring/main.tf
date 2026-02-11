variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

output "alarm_namespace" {
  value       = "${var.name_prefix}-alarms"
  description = "Placeholder monitoring namespace."
}
