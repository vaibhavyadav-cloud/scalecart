# The EKS control plane + a small ALWAYS-ON managed node group (the
# "floor" capacity this platform needs even at 3am with zero traffic),
# plus the IAM/OIDC plumbing that lets pods assume AWS IAM roles directly
# (IRSA) instead of nodes holding broad IAM permissions every pod on them
# inherits. Karpenter (installed post-cluster-creation by Ansible, see
# docs/13-ansible.md) handles all BURST capacity on top of this floor -
# that split is deliberate: a managed node group is simple and reliable
# for steady-state capacity, Karpenter is faster and more cost-efficient
# for reacting to spiky HPA-driven scale-out. See docs/14-scaling-to-1m-users.md.

resource "aws_iam_role" "cluster" {
  name = "${var.name}-eks-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = "${var.name}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true   # restrict to a CIDR allowlist in a real prod account; left open here for portfolio-demo simplicity
  }

  # Control-plane audit/authenticator logs shipped to CloudWatch - "who
  # did what to the cluster" is the first thing you need during a
  # security incident, and it's off by default in EKS.
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# IRSA: lets a Kubernetes ServiceAccount assume a real AWS IAM role via
# OIDC federation, with no static AWS key anywhere. This is the identity
# provider terraform/modules/iam's per-service roles trust.
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

resource "aws_iam_role" "node_group" {
  name = "${var.name}-eks-node-group"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "baseline" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-baseline"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"   # baseline floor stays on-demand for predictability; Karpenter's burst NodePool (Ansible-managed) is where Spot is used for cost savings

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = { "scalecart.io/capacity-type" = "baseline" }
  tags   = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]
}
