variable "aws_region" {
  type        = string
  description = "AWS region for this environment."
  default     = "ap-northeast-1"
}

variable "root_domain" {
  type        = string
  description = "Root domain name for Route53 hosted zone."
}
