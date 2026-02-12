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

module "ecs_service" {
  source      = "../../modules/ecs_service"
  name_prefix = local.name_prefix
  environment = local.environment
  enabled     = var.runtime_enabled
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.shared.outputs.private_subnet_ids
  target_group_arn   = module.alb.target_group_arn
  alb_security_group_id = module.alb.security_group_id
  container_image    = var.api_container_image
  container_port     = var.api_container_port
  desired_count      = var.api_desired_count
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
  container_port = var.api_container_port
}

module "waf" {
  source      = "../../modules/waf"
  name_prefix = local.name_prefix
  environment = local.environment
}

module "cloudfront" {
  source      = "../../modules/cloudfront"
  name_prefix = local.name_prefix
  environment = local.environment
}

module "app_s3" {
  source      = "../../modules/app_s3"
  name_prefix = local.name_prefix
  environment = local.environment
}

module "monitoring" {
  source      = "../../modules/monitoring"
  name_prefix = local.name_prefix
  environment = local.environment
}

module "cognito_auth" {
  source      = "../../modules/cognito_auth"
  name_prefix = local.name_prefix
  environment = local.environment
  root_domain = var.root_domain
}
