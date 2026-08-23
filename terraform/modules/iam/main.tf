# IRSA (IAM Roles for Service Accounts): each of these roles trusts ONE
# specific Kubernetes ServiceAccount (by namespace + name, verified via
# the EKS OIDC provider) to assume it. A pod running as that
# ServiceAccount gets temporary AWS credentials injected automatically -
# no static AWS access key ever exists in a Secret, an env var, or a
# container image. This is what the `serviceAccount.irsaRoleArn` value in
# every helm/<service>/values-prod.yaml ultimately points at. See
# docs/15-security-hardening.md.

locals {
  # Every backend service gets a role scoped to read exactly its own
  # secret in Secrets Manager - auth-service's role cannot read
  # payment-service's DB credentials, enforced by IAM, not convention.
  service_roles = var.service_secret_arns
}

data "aws_iam_policy_document" "assume_role" {
  for_each = local.service_roles
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:scalecart-prod:${each.key}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service" {
  for_each           = local.service_roles
  name               = "${var.name}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.key].json
  tags               = var.tags
}

data "aws_iam_policy_document" "read_own_secret" {
  for_each = local.service_roles
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [each.value]
  }
}

resource "aws_iam_role_policy" "read_own_secret" {
  for_each = local.service_roles
  name     = "read-own-secret"
  role     = aws_iam_role.service[each.key].id
  policy   = data.aws_iam_policy_document.read_own_secret[each.key].json
}

# ---------- Cluster add-on roles (installed by Ansible, not Helm) ----------

data "aws_iam_policy_document" "external_secrets_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets-sa"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "external_secrets_read_all" {
  name = "read-scalecart-secrets"
  role = aws_iam_role.external_secrets.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:*:*:secret:scalecart/*"
    }]
  })
}

data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

# The full AWSLoadBalancerControllerIAMPolicy JSON is long-lived and
# maintained upstream by AWS - referenced here rather than reproduced, to
# avoid this module silently drifting out of date with what the
# controller actually needs. See ansible/roles/aws-load-balancer-controller.
resource "aws_iam_role" "lb_controller" {
  name               = "${var.name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume.json
  tags               = var.tags
}
