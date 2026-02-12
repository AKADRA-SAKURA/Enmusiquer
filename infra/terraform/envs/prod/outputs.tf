output "ecs_service_name" {
  value       = module.ecs_service.service_name
  description = "ECS service name for prod."
}

output "db_identifier" {
  value       = module.rds_postgres.db_identifier
  description = "RDS identifier for prod."
}

output "alb_name" {
  value       = module.alb.alb_name
  description = "ALB name for prod."
}

output "app_bucket_name" {
  value       = module.app_s3.bucket_name
  description = "App bucket name for prod."
}

output "shared_vpc_id" {
  value       = data.terraform_remote_state.shared.outputs.vpc_id
  description = "Shared VPC ID referenced by prod."
}

output "shared_private_subnet_ids" {
  value       = data.terraform_remote_state.shared.outputs.private_subnet_ids
  description = "Shared private subnet IDs referenced by prod."
}
