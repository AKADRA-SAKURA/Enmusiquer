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
  environment = "shared"
  project     = "enmusiquer"
  name_prefix = "enm-shared"
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

module "network_shared" {
  source      = "../../modules/network_shared"
  name_prefix = local.name_prefix
  environment = local.environment
}

module "ecr_shared" {
  source            = "../../modules/ecr_shared"
  repository_prefix = "enm"
  environment       = local.environment
}

module "route53_shared" {
  source      = "../../modules/route53_shared"
  root_domain = var.root_domain
  environment = local.environment
}
