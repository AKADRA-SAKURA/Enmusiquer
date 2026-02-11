output "vpc_name" {
  value       = module.network_shared.vpc_name
  description = "Shared VPC name."
}

output "repository_namespace" {
  value       = module.ecr_shared.repository_namespace
  description = "Shared ECR namespace."
}

output "hosted_zone_name" {
  value       = module.route53_shared.hosted_zone_name
  description = "Shared Route53 hosted zone name."
}
