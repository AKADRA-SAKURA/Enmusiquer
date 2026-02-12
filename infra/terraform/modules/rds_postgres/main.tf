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
  description = "VPC ID for database security group."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for DB subnet group."
}

variable "app_security_group_id" {
  type        = string
  description = "Application security group ID allowed to connect to PostgreSQL."
  default     = null
}

variable "db_name" {
  type        = string
  description = "Initial database name."
  default     = "enmusiquer"
}

variable "db_username" {
  type        = string
  description = "Master username."
  default     = "enmadmin"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB."
  default     = 20
}

variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ deployment."
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "Backup retention days."
  default     = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection."
  default     = true
}

resource "aws_security_group" "rds" {
  count = var.enabled ? 1 : 0

  name        = "${var.name_prefix}-rds-sg"
  description = "RDS PostgreSQL security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_app" {
  count = var.enabled && var.app_security_group_id != null ? 1 : 0

  security_group_id            = aws_security_group.rds[0].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = var.app_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.enabled ? 1 : 0

  security_group_id = aws_security_group.rds[0].id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_db_subnet_group" "this" {
  count = var.enabled ? 1 : 0

  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.name_prefix}-db-subnets"
  }
}

resource "aws_db_instance" "this" {
  count = var.enabled ? 1 : 0

  identifier                    = "${var.name_prefix}-postgres"
  engine                        = "postgres"
  instance_class                = var.instance_class
  allocated_storage             = var.allocated_storage
  storage_type                  = "gp3"
  storage_encrypted             = true
  db_name                       = var.db_name
  username                      = var.db_username
  manage_master_user_password   = true
  db_subnet_group_name          = aws_db_subnet_group.this[0].name
  vpc_security_group_ids        = [aws_security_group.rds[0].id]
  backup_retention_period       = var.backup_retention_period
  multi_az                      = var.multi_az
  deletion_protection           = var.deletion_protection
  publicly_accessible           = false
  skip_final_snapshot           = !var.deletion_protection
  auto_minor_version_upgrade    = true

  tags = {
    Name = "${var.name_prefix}-postgres"
  }
}

output "db_identifier" {
  value       = var.enabled ? aws_db_instance.this[0].id : null
  description = "RDS identifier."
}

output "db_endpoint" {
  value       = var.enabled ? aws_db_instance.this[0].address : null
  description = "RDS endpoint address."
}

output "db_secret_arn" {
  value       = var.enabled ? try(aws_db_instance.this[0].master_user_secret[0].secret_arn, null) : null
  description = "Secrets Manager ARN for managed DB master password."
}
