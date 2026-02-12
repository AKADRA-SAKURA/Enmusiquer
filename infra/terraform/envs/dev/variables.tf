variable "aws_region" {
  type        = string
  description = "AWS region for this environment."
  default     = "ap-northeast-1"
}

variable "root_domain" {
  type        = string
  description = "Root domain managed in Route53 shared environment."
}

variable "shared_state_bucket" {
  type        = string
  description = "S3 bucket name that stores shared terraform state."
}

variable "shared_state_key" {
  type        = string
  description = "State key for shared environment."
  default     = "enm/shared/terraform.tfstate"
}

variable "shared_state_region" {
  type        = string
  description = "AWS region for shared terraform state bucket."
  default     = "ap-northeast-1"
}

variable "runtime_enabled" {
  type        = bool
  description = "Create runtime resources (ALB/ECS/RDS) when true."
  default     = false
}

variable "api_container_image" {
  type        = string
  description = "Container image URI for ECS service (used when use_shared_ecr_image is false)."
  default     = "public.ecr.aws/docker/library/nginx:stable-alpine"
}

variable "use_shared_ecr_image" {
  type        = bool
  description = "Use shared ECR backend repository URL for ECS image."
  default     = true
}

variable "api_image_tag" {
  type        = string
  description = "Image tag used with shared ECR backend repository."
  default     = "latest"
}

variable "api_desired_count" {
  type        = number
  description = "Desired task count for ECS service."
  default     = 1
}

variable "api_environment_variables" {
  type        = map(string)
  description = "Additional environment variables for ECS container."
  default     = {}
}

variable "api_secret_arns" {
  type        = map(string)
  description = "Additional ECS container secrets (name => secret ARN)."
  default     = {}
}

variable "api_container_port" {
  type        = number
  description = "Container port for ALB and ECS."
  default     = 80
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  type        = bool
  description = "Enable Multi-AZ for RDS."
  default     = false
}

variable "db_backup_retention_period" {
  type        = number
  description = "RDS backup retention days."
  default     = 1
}

variable "db_deletion_protection" {
  type        = bool
  description = "Enable RDS deletion protection."
  default     = false
}

variable "edge_enabled" {
  type        = bool
  description = "Enable edge resources (CloudFront/WAF) when true."
  default     = false
}

variable "waf_rate_limit" {
  type        = number
  description = "WAF rate-based rule limit per 5 minutes."
  default     = 2000
}

variable "cloudfront_aliases" {
  type        = list(string)
  description = "CloudFront alternate domain names."
  default     = []
}

variable "cloudfront_acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN in us-east-1 for CloudFront aliases."
  default     = null
}

variable "monitoring_enabled" {
  type        = bool
  description = "Enable CloudWatch alarms when true."
  default     = false
}

variable "monitoring_alarm_actions" {
  type        = list(string)
  description = "CloudWatch alarm action ARNs (for example SNS topic ARN)."
  default     = []
}

variable "create_dns_records" {
  type        = bool
  description = "Create Route53 records for dev when true."
  default     = false
}

variable "api_record_name" {
  type        = string
  description = "Subdomain label for API record."
  default     = "api-dev"
}

variable "cdn_record_name" {
  type        = string
  description = "Subdomain label for CDN record."
  default     = "cdn-dev"
}
