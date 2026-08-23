locals {
  name = "scalecart-prod"
  tags = { Project = "scalecart", Environment = "prod" }
}

module "network" {
  source   = "../../modules/network"
  name     = local.name
  vpc_cidr = "10.0.0.0/16"
  azs      = var.azs
  tags     = local.tags
}

module "eks" {
  source              = "../../modules/eks"
  name                = local.name
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  public_subnet_ids   = module.network.public_subnet_ids
  node_instance_types = ["m6i.large"]
  node_min_size       = 3
  node_max_size       = 9
  node_desired_size   = 3
  tags                = local.tags
}

# One EKS-node-group security group is what every database module's
# `allowed_security_group_ids` needs - the EKS module doesn't expose this
# directly (it's created implicitly by the node group), so it's looked up
# here via a data source instead of threading it through as an extra
# module output.
data "aws_security_groups" "eks_nodes" {
  filter {
    name   = "tag:aws:eks:cluster-name"
    values = [module.eks.cluster_name]
  }
}

# ---------- Database-per-service: 3 independent Postgres instances ----------
module "auth_db" {
  source                     = "../../modules/rds-postgres"
  name                       = "${local.name}-auth"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  database_name              = "scalecart_auth"
  multi_az                   = true
  tags                       = local.tags
}

module "orders_db" {
  source                     = "../../modules/rds-postgres"
  name                       = "${local.name}-orders"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  database_name              = "scalecart_orders"
  multi_az                   = true
  # orders is the first table to hit read-heavy pressure at scale (every
  # "my orders" page view) - see docs/14-scaling-to-1m-users.md.
  read_replica_count = 1
  tags               = local.tags
}

module "payments_db" {
  source                     = "../../modules/rds-postgres"
  name                       = "${local.name}-payments"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  database_name              = "scalecart_payments"
  multi_az                   = true
  tags                       = local.tags
}

# ---------- Product catalog (DocumentDB) ----------
module "product_db" {
  source                     = "../../modules/documentdb"
  name                       = "${local.name}-products"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  instance_count             = 2
  tags                       = local.tags
}

# ---------- Cart + notification dedup (Redis) ----------
module "redis" {
  source                     = "../../modules/elasticache-redis"
  name                       = "${local.name}-redis"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  num_cache_nodes            = 2
  tags                       = local.tags
}

# ---------- Kafka (managed, production path - see docs/08) ----------
module "kafka" {
  source                     = "../../modules/msk"
  name                       = "${local.name}-kafka"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  broker_count               = 3
  tags                       = local.tags
}

# ---------- Container registry ----------
module "ecr" {
  source = "../../modules/ecr"
  tags   = local.tags
}

# ---------- Static frontend hosting + CDN ----------
module "frontend_cdn" {
  source              = "../../modules/s3-cloudfront"
  name                = local.name
  domain_name         = var.domain_name
  acm_certificate_arn = var.acm_certificate_arn
  tags                = local.tags
}

# ---------- IRSA roles, one per service + cluster add-ons ----------
module "iam" {
  source            = "../../modules/iam"
  name              = local.name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  service_secret_arns = {
    auth-service    = module.auth_db.secret_arn
    order-service   = module.orders_db.secret_arn
    payment-service = module.payments_db.secret_arn
    product-service = module.product_db.secret_arn
  }
  tags = local.tags
}
