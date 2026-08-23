# Dev deliberately costs a fraction of prod: single-instance databases
# (no read replicas, no Multi-AZ), a smaller node floor, and no MSK -
# Kafka in dev runs in-cluster via Strimzi instead (k8s/kafka/), applied
# through ArgoCD like any other manifest, not provisioned by Terraform at
# all. See docs/12-terraform-iac.md for the full dev-vs-prod cost/safety
# tradeoff table.
locals {
  name = "scalecart-dev"
  tags = { Project = "scalecart", Environment = "dev" }
}

module "network" {
  source   = "../../modules/network"
  name     = local.name
  vpc_cidr = "10.1.0.0/16"
  azs      = var.azs
  tags     = local.tags
}

module "eks" {
  source              = "../../modules/eks"
  name                = local.name
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  public_subnet_ids   = module.network.public_subnet_ids
  node_instance_types = ["t3.large"]
  node_min_size       = 2
  node_max_size       = 4
  node_desired_size   = 2
  tags                = local.tags
}

data "aws_security_groups" "eks_nodes" {
  filter {
    name   = "tag:aws:eks:cluster-name"
    values = [module.eks.cluster_name]
  }
}

module "auth_db" {
  source                     = "../../modules/rds-postgres"
  name                       = "${local.name}-auth"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  database_name              = "scalecart_auth"
  instance_class             = "db.t4g.micro"
  multi_az                   = false
  backup_retention_days      = 1
  tags                       = local.tags
}

module "orders_db" {
  source                     = "../../modules/rds-postgres"
  name                       = "${local.name}-orders"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  database_name              = "scalecart_orders"
  instance_class             = "db.t4g.micro"
  multi_az                   = false
  backup_retention_days      = 1
  tags                       = local.tags
}

module "payments_db" {
  source                     = "../../modules/rds-postgres"
  name                       = "${local.name}-payments"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  database_name              = "scalecart_payments"
  instance_class             = "db.t4g.micro"
  multi_az                   = false
  backup_retention_days      = 1
  tags                       = local.tags
}

module "product_db" {
  source                     = "../../modules/documentdb"
  name                       = "${local.name}-products"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  instance_class             = "db.t4g.medium"
  instance_count             = 1 # no failover replica in dev
  tags                       = local.tags
}

module "redis" {
  source                     = "../../modules/elasticache-redis"
  name                       = "${local.name}-redis"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  allowed_security_group_ids = data.aws_security_groups.eks_nodes.ids
  node_type                  = "cache.t4g.micro"
  num_cache_nodes            = 0 # single node, no automatic failover - acceptable for dev
  tags                       = local.tags
}

# No aws_msk_cluster module call here - dev/staging use the in-cluster
# Strimzi Kafka deployment (k8s/kafka/) instead of MSK, see the file
# header comment above.

module "ecr" {
  source = "../../modules/ecr"
  tags   = local.tags
}

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
