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
  description = "VPC ID for ECS security group."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for ECS tasks."
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign public IP to ECS tasks."
  default     = false
}

variable "target_group_arn" {
  type        = string
  description = "Target group ARN for service registration."
  default     = null
}

variable "alb_security_group_id" {
  type        = string
  description = "ALB security group ID to allow ingress from."
  default     = null
}

variable "container_image" {
  type        = string
  description = "Container image URI."
  default     = "public.ecr.aws/docker/library/nginx:stable-alpine"
}

variable "container_port" {
  type        = number
  description = "Container port."
  default     = 80
}

variable "cpu" {
  type        = number
  description = "Task CPU units."
  default     = 256
}

variable "memory" {
  type        = number
  description = "Task memory (MiB)."
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "Desired service task count."
  default     = 1
}

variable "environment_variables" {
  type        = map(string)
  description = "Container environment variables."
  default     = {}
}

variable "secrets" {
  type        = map(string)
  description = "Container secret references (name => secret ARN or SSM parameter ARN)."
  default     = {}
}

locals {
  container_environment = [
    for key in sort(keys(var.environment_variables)) : {
      name  = key
      value = var.environment_variables[key]
    }
  ]

  container_secrets = [
    for key in sort(keys(var.secrets)) : {
      name      = key
      valueFrom = var.secrets[key]
    }
  ]
}

resource "aws_ecs_cluster" "this" {
  count = var.enabled ? 1 : 0

  name = "${var.name_prefix}-cluster"
}

resource "aws_cloudwatch_log_group" "ecs" {
  count = var.enabled ? 1 : 0

  name              = "/ecs/${var.name_prefix}-api"
  retention_in_days = 30
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  count = var.enabled ? 1 : 0

  name               = "${var.name_prefix}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  count = var.enabled ? 1 : 0

  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_runtime_access" {
  statement {
    sid = "AllowReadSecretsAndParameters"

    actions = [
      "secretsmanager:GetSecretValue",
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowKmsDecryptForSecrets"

    actions = ["kms:Decrypt"]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "execution_runtime_access" {
  count = var.enabled ? 1 : 0

  name   = "${var.name_prefix}-ecs-exec-runtime-access"
  role   = aws_iam_role.execution[0].id
  policy = data.aws_iam_policy_document.execution_runtime_access.json
}

resource "aws_iam_role" "task" {
  count = var.enabled ? 1 : 0

  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_security_group" "ecs" {
  count = var.enabled ? 1 : 0

  name        = "${var.name_prefix}-ecs-sg"
  description = "ECS service security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  count = var.enabled ? 1 : 0

  security_group_id            = aws_security_group.ecs[0].id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = var.alb_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.enabled ? 1 : 0

  security_group_id = aws_security_group.ecs[0].id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_ecs_task_definition" "api" {
  count = var.enabled ? 1 : 0

  family                   = "${var.name_prefix}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution[0].arn
  task_role_arn            = aws_iam_role.task[0].arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = local.container_environment
      secrets     = local.container_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs[0].name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

data "aws_region" "current" {}

resource "aws_ecs_service" "this" {
  count = var.enabled ? 1 : 0

  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.this[0].id
  task_definition = aws_ecs_task_definition.api[0].arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs[0].id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api"
    container_port   = var.container_port
  }

  depends_on = [aws_iam_role_policy_attachment.execution]
}

output "service_name" {
  value       = var.enabled ? aws_ecs_service.this[0].name : null
  description = "ECS service name."
}

output "cluster_name" {
  value       = var.enabled ? aws_ecs_cluster.this[0].name : null
  description = "ECS cluster name."
}

output "security_group_id" {
  value       = var.enabled ? aws_security_group.ecs[0].id : null
  description = "ECS security group ID."
}
