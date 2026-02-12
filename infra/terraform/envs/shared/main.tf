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
  source               = "../../modules/network_shared"
  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ecr_shared" {
  source            = "../../modules/ecr_shared"
  repository_prefix = var.ecr_repository_prefix
  repository_names  = var.ecr_repository_names
}

module "route53_shared" {
  source                  = "../../modules/route53_shared"
  root_domain             = var.root_domain
  create_hosted_zone      = var.create_hosted_zone
  existing_hosted_zone_id = var.existing_hosted_zone_id
}
