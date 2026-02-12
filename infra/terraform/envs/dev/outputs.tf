output "ecs_service_name" {
  value       = module.ecs_service.service_name
  description = "ECS service name for dev."
}

output "api_container_image" {
  value       = local.api_image
  description = "Selected container image for dev ECS service."
}

output "db_identifier" {
  value       = module.rds_postgres.db_identifier
  description = "RDS identifier for dev."
}

output "alb_name" {
  value       = module.alb.alb_name
  description = "ALB name for dev."
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "ALB DNS name for dev."
}

output "app_bucket_name" {
  value       = module.app_s3.bucket_name
  description = "App bucket name for dev."
}

output "cloudfront_domain_name" {
  value       = module.cloudfront.distribution_domain_name
  description = "CloudFront domain name for dev."
}

output "cloudfront_distribution_id" {
  value       = module.cloudfront.distribution_id
  description = "CloudFront distribution ID for dev."
}

output "waf_web_acl_arn" {
  value       = module.waf.web_acl_arn
  description = "WAF web ACL ARN for dev."
}

output "monitoring_alarm_names" {
  value       = module.monitoring.alarm_names
  description = "CloudWatch alarm names for dev."
}

output "api_domain_name" {
  value       = try(aws_route53_record.api_alias[0].fqdn, null)
  description = "API domain name for dev."
}

output "cdn_domain_record_name" {
  value       = try(aws_route53_record.cdn_alias[0].fqdn, null)
  description = "CDN domain name for dev."
}

output "db_endpoint" {
  value       = module.rds_postgres.db_endpoint
  description = "RDS endpoint for dev."
}

output "db_secret_arn" {
  value       = module.rds_postgres.db_secret_arn
  description = "Secrets Manager ARN for dev DB credential."
}

output "cognito_user_pool_id" {
  value       = module.cognito_auth.user_pool_id
  description = "Cognito user pool ID for dev."
}

output "cognito_user_pool_client_id" {
  value       = module.cognito_auth.user_pool_client_id
  description = "Cognito app client ID for dev."
}

output "shared_vpc_id" {
  value       = data.terraform_remote_state.shared.outputs.vpc_id
  description = "Shared VPC ID referenced by dev."
}

output "shared_private_subnet_ids" {
  value       = data.terraform_remote_state.shared.outputs.private_subnet_ids
  description = "Shared private subnet IDs referenced by dev."
}
