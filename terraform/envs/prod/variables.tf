variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "domain_name" {
  type    = string
  default = "scalecart.example.com"
}

variable "acm_certificate_arn" {
  description = "Pre-issued ACM cert in us-east-1 for the CloudFront distribution - set via terraform.tfvars, not committed"
  type        = string
}
