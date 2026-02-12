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
  description = "Create CloudFront resources when true."
  default     = false
}

variable "origin_bucket_name" {
  type        = string
  description = "Origin S3 bucket name."
}

variable "origin_bucket_regional_domain_name" {
  type        = string
  description = "Origin S3 bucket regional domain name."
}

variable "web_acl_arn" {
  type        = string
  description = "WAF web ACL ARN to attach to CloudFront."
  default     = null
}

variable "aliases" {
  type        = list(string)
  description = "Alternate domain names (CNAMEs)."
  default     = []

  validation {
    condition     = length(var.aliases) == 0 || var.acm_certificate_arn != null
    error_message = "acm_certificate_arn is required when aliases is not empty."
  }
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN in us-east-1 for aliases."
  default     = null
}

variable "default_root_object" {
  type        = string
  description = "Default root object."
  default     = "index.html"
}

resource "aws_cloudfront_origin_access_control" "this" {
  count = var.enabled ? 1 : 0

  name                              = "${var.name_prefix}-oac"
  description                       = "Origin access control for ${var.name_prefix}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  count = var.enabled ? 1 : 0

  enabled             = true
  comment             = "${var.name_prefix}-cdn"
  default_root_object = var.default_root_object
  price_class         = "PriceClass_200"
  aliases             = var.aliases
  web_acl_id          = var.web_acl_arn

  origin {
    domain_name              = var.origin_bucket_regional_domain_name
    origin_id                = "s3-${var.origin_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.this[0].id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${var.origin_bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != null ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.acm_certificate_arn == null
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  count = var.enabled ? 1 : 0

  statement {
    sid = "AllowCloudFrontRead"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.origin_bucket_name}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this[0].arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = var.enabled ? 1 : 0

  bucket = var.origin_bucket_name
  policy = data.aws_iam_policy_document.bucket_policy[0].json
}

output "distribution_comment" {
  value       = var.enabled ? aws_cloudfront_distribution.this[0].comment : null
  description = "CloudFront distribution comment."
}

output "distribution_domain_name" {
  value       = var.enabled ? aws_cloudfront_distribution.this[0].domain_name : null
  description = "CloudFront distribution domain name."
}

output "distribution_id" {
  value       = var.enabled ? aws_cloudfront_distribution.this[0].id : null
  description = "CloudFront distribution ID."
}

output "distribution_hosted_zone_id" {
  value       = var.enabled ? aws_cloudfront_distribution.this[0].hosted_zone_id : null
  description = "CloudFront hosted zone ID for Route53 alias."
}
