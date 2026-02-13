terraform {
  required_version = ">= 1.6.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  environment = "dev"
  project     = "enmusiquer"
  name_prefix = "enm-dev"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = local.project
      Environment = local.environment
      ManagedBy   = "terraform"
    }
  }
}

data "terraform_remote_state" "shared" {
  backend = "s3"

  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.shared_state_region
  }
}

locals {
  api_fqdn            = "${var.api_record_name}.${var.root_domain}"
  cdn_fqdn            = "${var.cdn_record_name}.${var.root_domain}"
  shared_backend_repo = try(data.terraform_remote_state.shared.outputs.repository_urls["backend"], "")
  api_image           = var.use_shared_ecr_image ? "${local.shared_backend_repo}:${var.api_image_tag}" : var.api_container_image
  api_env             = merge(var.api_environment_variables, var.runtime_enabled ? { DB_HOST = module.rds_postgres.db_endpoint } : {})
  api_secrets         = merge(var.api_secret_arns, var.runtime_enabled ? { DB_MASTER_SECRET_ARN = module.rds_postgres.db_secret_arn } : {})
  monitoring_alarm_actions_effective = length(var.monitoring_alarm_actions) > 0 ? var.monitoring_alarm_actions : compact([module.discord_alerting.topic_arn])
}

check "shared_backend_repo_available" {
  assert {
    condition     = !var.use_shared_ecr_image || local.shared_backend_repo != ""
    error_message = "use_shared_ecr_image=true requires shared output repository_urls[\"backend\"]."
  }
}

module "ecs_service" {
  source      = "../../modules/ecs_service"
  name_prefix = local.name_prefix
  environment = local.environment
  enabled     = var.runtime_enabled
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids = var.api_use_public_subnets ? data.terraform_remote_state.shared.outputs.public_subnet_ids : data.terraform_remote_state.shared.outputs.private_subnet_ids
  assign_public_ip   = var.api_assign_public_ip
  target_group_arn   = module.alb.target_group_arn
  alb_security_group_id = module.alb.security_group_id
  container_image    = local.api_image
  container_port     = var.api_container_port
  desired_count      = var.api_desired_count
  environment_variables = local.api_env
  secrets               = local.api_secrets
}

module "rds_postgres" {
  source      = "../../modules/rds_postgres"
  name_prefix = local.name_prefix
  environment = local.environment
  enabled                  = var.runtime_enabled
  vpc_id                   = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids       = data.terraform_remote_state.shared.outputs.private_subnet_ids
  app_security_group_id    = module.ecs_service.security_group_id
  instance_class           = var.db_instance_class
  multi_az                 = var.db_multi_az
  backup_retention_period  = var.db_backup_retention_period
  deletion_protection      = var.db_deletion_protection
}

module "alb" {
  source      = "../../modules/alb"
  name_prefix = local.name_prefix
  environment = local.environment
  enabled     = var.runtime_enabled
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.shared.outputs.public_subnet_ids
  container_port   = var.api_container_port
  health_check_path = var.api_health_check_path
}

module "waf" {
  source      = "../../modules/waf"
  name_prefix = local.name_prefix
  environment = local.environment
  enabled     = var.edge_enabled && var.runtime_enabled
  resource_arn = module.alb.alb_arn
  rate_limit  = var.waf_rate_limit
}

module "cloudfront" {
  source      = "../../modules/cloudfront"
  name_prefix = local.name_prefix
  environment = local.environment
  enabled     = var.edge_enabled
  origin_bucket_name                 = module.app_s3.bucket_name
  origin_bucket_regional_domain_name = module.app_s3.bucket_regional_domain_name
  web_acl_arn                        = null
  aliases                            = var.cloudfront_aliases
  acm_certificate_arn                = var.cloudfront_acm_certificate_arn
}

module "app_s3" {
  source      = "../../modules/app_s3"
  name_prefix = local.name_prefix
  environment = local.environment
}

module "discord_alerting" {
  source      = "../../modules/discord_alerting"
  name_prefix = local.name_prefix
  environment = local.environment
  enabled     = var.discord_alert_enabled
  discord_webhook_url = var.discord_webhook_url
}

module "monitoring" {
  source      = "../../modules/monitoring"
  name_prefix = local.name_prefix
  environment = local.environment
  enabled          = var.monitoring_enabled && var.runtime_enabled
  ecs_cluster_name = module.ecs_service.cluster_name
  ecs_service_name = module.ecs_service.service_name
  alb_arn_suffix   = module.alb.alb_arn_suffix
  db_identifier    = module.rds_postgres.db_identifier
  alarm_actions    = local.monitoring_alarm_actions_effective
}

module "cognito_auth" {
  source      = "../../modules/cognito_auth"
  name_prefix = local.name_prefix
  environment = local.environment
  root_domain = var.root_domain
}

resource "aws_route53_record" "api_alias" {
  count = var.create_dns_records && var.runtime_enabled ? 1 : 0

  zone_id = data.terraform_remote_state.shared.outputs.hosted_zone_id
  name    = local.api_fqdn
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cdn_alias" {
  count = var.create_dns_records && var.edge_enabled ? 1 : 0

  zone_id = data.terraform_remote_state.shared.outputs.hosted_zone_id
  name    = local.cdn_fqdn
  type    = "A"

  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = module.cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
