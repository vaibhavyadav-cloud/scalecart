# Backs both cart-service (cart state) and notification-service (event
# dedup) - see docs/03-databases-per-service.md for why these two use
# Redis instead of a durable store, and docs/14-scaling-to-1m-users.md
# for why Redis specifically is what makes the cart read/write path cheap
# at high QPS. Replication group (not a single cache node) gives automatic
# failover to a replica if the primary node fails.
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-redis-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                = "ScaleCart Redis - ${var.name}"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = var.node_type
  num_cache_clusters         = 1 + var.num_cache_nodes
  automatic_failover_enabled = var.num_cache_nodes > 0
  multi_az_enabled           = var.num_cache_nodes > 0

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = var.tags
}
