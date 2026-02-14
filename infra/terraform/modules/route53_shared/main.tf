variable "root_domain" {
  type        = string
  description = "Root domain managed by Route53."
}

variable "create_hosted_zone" {
  type        = bool
  description = "Create Route53 hosted zone when true."
  default     = true
}

variable "existing_hosted_zone_id" {
  type        = string
  description = "Use existing hosted zone ID when create_hosted_zone is false."
  default     = null
}

check "existing_hosted_zone_id_required_when_reusing_zone" {
  assert {
    condition     = var.create_hosted_zone || (var.existing_hosted_zone_id != null && trimspace(var.existing_hosted_zone_id) != "")
    error_message = "existing_hosted_zone_id is required when create_hosted_zone is false."
  }
}

resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0

  name = var.root_domain

  tags = {
    Name = var.root_domain
  }
}

locals {
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.existing_hosted_zone_id
}

output "hosted_zone_id" {
  value       = local.hosted_zone_id
  description = "Route53 hosted zone ID."
}

output "hosted_zone_name" {
  value       = var.root_domain
  description = "Route53 hosted zone name."
}

output "name_servers" {
  value       = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
  description = "Authoritative name servers if hosted zone is created."
}
