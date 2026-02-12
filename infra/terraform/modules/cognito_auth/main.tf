variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
}

variable "environment" {
  type        = string
  description = "Environment name."
}

variable "root_domain" {
  type        = string
  description = "Root domain for auth callbacks."
}

variable "callback_urls" {
  type        = list(string)
  description = "Allowed callback URLs."
  default     = []
}

variable "logout_urls" {
  type        = list(string)
  description = "Allowed logout URLs."
  default     = []
}

locals {
  default_callback_urls = ["https://app.${var.root_domain}/auth/callback"]
  default_logout_urls   = ["https://app.${var.root_domain}/"]
}

resource "aws_cognito_user_pool" "this" {
  name = "${var.name_prefix}-users"

  deletion_protection = var.environment == "prod" ? "ACTIVE" : "INACTIVE"

  mfa_configuration = "OFF"

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]
}

resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.name_prefix}-app-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"

  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = length(var.callback_urls) > 0 ? var.callback_urls : local.default_callback_urls
  logout_urls                          = length(var.logout_urls) > 0 ? var.logout_urls : local.default_logout_urls
}

output "user_pool_name" {
  value       = aws_cognito_user_pool.this.name
  description = "Cognito user pool name."
}

output "user_pool_id" {
  value       = aws_cognito_user_pool.this.id
  description = "Cognito user pool ID."
}

output "user_pool_client_id" {
  value       = aws_cognito_user_pool_client.app.id
  description = "Cognito app client ID."
}
