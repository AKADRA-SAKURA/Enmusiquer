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
  environment = "prod"
  project     = "enmusiquer"
  name_prefix = "enm-prod"
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

module "ecs_service" {
  source      = "../../modules/ecs_service"
  name_prefix = local.name_prefix
  environment = local.environment
}

module "rds_postgres" {
  source      = "../../modules/rds_postgres"
  name_prefix = local.name_prefix
  environment = local.environment
}

module "alb" {
  source      = "../../modules/alb"
  name_prefix = local.name_prefix
  environment = local.environment
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
