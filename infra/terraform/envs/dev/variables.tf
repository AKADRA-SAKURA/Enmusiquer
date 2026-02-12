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
