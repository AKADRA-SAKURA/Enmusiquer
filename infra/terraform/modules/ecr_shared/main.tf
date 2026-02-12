variable "repository_prefix" {
  type        = string
  description = "Prefix for ECR repositories."
}

variable "repository_names" {
  type        = list(string)
  description = "List of logical repository names."
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = "${var.repository_prefix}/${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

output "repository_namespace" {
  value       = var.repository_prefix
  description = "Shared ECR repository prefix."
}

output "repository_urls" {
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
  description = "Repository URL by logical name."
}
