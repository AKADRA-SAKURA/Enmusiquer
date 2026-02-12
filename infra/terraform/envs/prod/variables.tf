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
  description = "Container image URI for ECS service."
  default     = "public.ecr.aws/docker/library/nginx:stable-alpine"
}

variable "api_desired_count" {
  type        = number
  description = "Desired task count for ECS service."
  default     = 1
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
  default     = 7
}

variable "db_deletion_protection" {
  type        = bool
  description = "Enable RDS deletion protection."
  default     = true
}
