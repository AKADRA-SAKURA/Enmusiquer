variable "aws_region" {
  type        = string
  description = "AWS region for this environment."
  default     = "ap-northeast-1"
}

variable "root_domain" {
  type        = string
  description = "Root domain name for Route53 hosted zone."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for shared VPC."
  default     = "10.20.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "AZs used for shared subnets."
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs."
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs."
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "ecr_repository_prefix" {
  type        = string
  description = "ECR repository prefix (namespace)."
  default     = "enm"
}

variable "ecr_repository_names" {
  type        = list(string)
  description = "ECR repository names to create."
  default     = ["backend", "frontend"]
}

variable "ecr_enable_lifecycle_policy" {
  type        = bool
  description = "Enable lifecycle policy for shared ECR repositories."
  default     = true
}

variable "ecr_max_image_count" {
  type        = number
  description = "Maximum number of images to keep in each ECR repository."
  default     = 50
}

variable "create_hosted_zone" {
  type        = bool
  description = "Create hosted zone in Route53 when true."
  default     = true
}

variable "existing_hosted_zone_id" {
  type        = string
  description = "Existing hosted zone ID when create_hosted_zone is false."
  default     = null
}
