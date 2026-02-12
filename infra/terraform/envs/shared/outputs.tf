output "vpc_name" {
  value       = module.network_shared.vpc_name
  description = "Shared VPC name."
}

output "vpc_id" {
  value       = module.network_shared.vpc_id
  description = "Shared VPC ID."
}

output "public_subnet_ids" {
  value       = module.network_shared.public_subnet_ids
  description = "Shared public subnet IDs."
}

output "private_subnet_ids" {
  value       = module.network_shared.private_subnet_ids
  description = "Shared private subnet IDs."
}

output "repository_namespace" {
  value       = module.ecr_shared.repository_namespace
  description = "Shared ECR namespace."
}

output "repository_urls" {
  value       = module.ecr_shared.repository_urls
  description = "Shared ECR repository URLs."
}

output "hosted_zone_name" {
  value       = module.route53_shared.hosted_zone_name
  description = "Shared Route53 hosted zone name."
}

output "hosted_zone_id" {
  value       = module.route53_shared.hosted_zone_id
  description = "Shared Route53 hosted zone ID."
}

output "name_servers" {
  value       = module.route53_shared.name_servers
  description = "Authoritative name servers when hosted zone is created."
}
