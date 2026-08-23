# Hosts the Next.js static export (services/frontend, `next build` with
# `output: "export"` - see docs/04-docker-optimization.md) directly from
# S3, fronted by CloudFront. This is an ALTERNATIVE delivery path to the
# containerized Nginx frontend Deployment in k8s/base/16-frontend.yaml -
# a real production setup picks ONE (this one, for pure static content,
# is cheaper and faster than running pods for something with no server
# logic), but both are provided so the same codebase demonstrates both
# patterns. See docs/01-architecture.md.
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.name}-frontend"
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudFront reaches the bucket via Origin Access Control, not a public
# bucket policy - the bucket itself stays fully private.
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]
  price_class         = "PriceClass_100" # US/Canada/Europe edge locations - tune per actual user geography

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # AWS managed "CachingOptimized" policy
  }

  # SPA fallback: any path CloudFront can't find (a Next.js client-side
  # route) serves index.html instead of a CloudFront 403/404 page.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipalReadOnly"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn }
      }
    }]
  })
}

# Also doubles as the CI artifact bucket (SBOMs, Terraform plan exports
# archived long-term outside GitHub's 90-day retention) - see docs/11-github-actions-cicd.md.
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.name}-ci-artifacts"
  tags   = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"
    filter {} # applies to every object in the bucket - required explicitly since provider v5, else this rule is ambiguous
    expiration { days = 365 }
  }
}
