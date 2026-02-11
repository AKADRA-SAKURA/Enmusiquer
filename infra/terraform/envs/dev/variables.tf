variable "aws_region" {
  type        = string
  description = "AWS region for this environment."
  default     = "ap-northeast-1"
}

variable "root_domain" {
  type        = string
  description = "Root domain managed in Route53 shared environment."
}
