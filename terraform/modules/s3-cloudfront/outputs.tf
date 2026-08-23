output "distribution_domain_name" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.id
}

output "artifacts_bucket_name" {
  value = aws_s3_bucket.artifacts.id
}
