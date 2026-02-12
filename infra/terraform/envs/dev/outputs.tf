output "ecs_service_name" {
  value       = module.ecs_service.service_name
  description = "ECS service name for dev."
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
