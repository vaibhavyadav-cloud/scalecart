terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state in S3 + a DynamoDB table for locking - without locking,
  # two people (or a person and a CI run) applying at the same time can
  # corrupt state. Bootstrap this bucket/table once, by hand, before this
  # backend block can be used (chicken-and-egg: Terraform can't create its
  # own remote backend on its first run) - see docs/12-terraform-iac.md.
  backend "s3" {
    bucket         = "scalecart-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "scalecart-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "scalecart"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
