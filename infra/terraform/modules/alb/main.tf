variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "enabled" {
  type        = bool
  description = "Create resources when true."
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for ALB and target group."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB."
}

variable "container_port" {
  type        = number
  description = "Backend container port."
  default     = 80
}

variable "health_check_path" {
  type        = string
  description = "Health check path for target group."
  default     = "/health"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listener."
  default     = null
}

variable "enable_https_listener" {
  type        = bool
  description = "Enable HTTPS listener when true."
  default     = false
}

locals {
  # aws_lb_target_group.name_prefix is limited to 6 chars.
  target_group_name_prefix = substr(replace(var.name_prefix, "-", ""), 0, 6)
}

resource "aws_security_group" "alb" {
  count = var.enabled ? 1 : 0

  name        = "${var.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  count = var.enabled ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  count = var.enabled && var.enable_https_listener ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.enabled ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_lb" "this" {
  count = var.enabled ? 1 : 0

  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "api" {
  count = var.enabled ? 1 : 0

  name_prefix = local.target_group_name_prefix
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  count = var.enabled ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }
}

resource "aws_lb_listener" "https" {
  count = var.enabled && var.enable_https_listener && var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }
}

output "alb_name" {
  value       = var.enabled ? aws_lb.this[0].name : null
  description = "ALB name."
}

output "alb_dns_name" {
  value       = var.enabled ? aws_lb.this[0].dns_name : null
  description = "ALB DNS name."
}

output "alb_arn" {
  value       = var.enabled ? aws_lb.this[0].arn : null
  description = "ALB ARN."
}

output "alb_arn_suffix" {
  value       = var.enabled ? aws_lb.this[0].arn_suffix : null
  description = "ALB ARN suffix for CloudWatch metrics."
}

output "alb_zone_id" {
  value       = var.enabled ? aws_lb.this[0].zone_id : null
  description = "ALB hosted zone ID for Route53 alias."
}

output "target_group_arn" {
  value       = var.enabled ? aws_lb_target_group.api[0].arn : null
  description = "Target group ARN for API service."
}

output "security_group_id" {
  value       = var.enabled ? aws_security_group.alb[0].id : null
  description = "ALB security group ID."
}
