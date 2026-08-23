# This project's actual CI pipeline (.github/workflows/reusable-build-scan-push.yml)
# pushes to GHCR, not ECR - GHCR needs no cloud credentials to demo the
# pipeline end-to-end. This module provisions the AWS-native alternative
# for a real deployment that wants images to never leave AWS: swap
# `env.REGISTRY`/`env.IMAGE` in that workflow to point here, and update
# the `image.repository` values in every helm/<service>/values.yaml
# accordingly. See docs/12-terraform-iac.md.
resource "aws_ecr_repository" "this" {
  for_each             = toset(var.repository_names)
  name                 = "scalecart/${each.value}"
  image_tag_mutability = "IMMUTABLE" # a given tag (git SHA) can never be overwritten - what's deployed is provably what was scanned by Trivy

  image_scanning_configuration {
    scan_on_push = true # AWS's own basic scan, in addition to (not instead of) the Trivy scan in CI - defense in depth
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = var.tags
}

# Keeps the last 20 tagged images (git SHAs) and expires anything older -
# without this, 7 repos accumulate an image per commit forever.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}
