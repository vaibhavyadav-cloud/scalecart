# Amazon DocumentDB - the managed, MongoDB-wire-protocol-compatible
# equivalent of the `mongo` container product-service talks to in
# docker-compose. product-service's code doesn't know or care which one
# is on the other end of MONGO_URI - see docs/03-databases-per-service.md.
resource "aws_docdb_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-docdb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 27017
    to_port         = 27017
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

resource "random_password" "master" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "credentials" {
  name = "scalecart/${var.name}/db-credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.credentials.id
  secret_string = jsonencode({
    username  = var.master_username
    password  = random_password.master.result
    mongo_uri = "mongodb://${var.master_username}:${random_password.master.result}@${aws_docdb_cluster.this.endpoint}:27017/?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  })
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier      = var.name
  engine                  = "docdb"
  master_username         = var.master_username
  master_password         = random_password.master.result
  db_subnet_group_name    = aws_docdb_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.this.id]
  storage_encrypted       = true
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot     = true # portfolio/demo default - flip to false + set final_snapshot_identifier for a real prod account
  tags                    = var.tags
}

resource "aws_docdb_cluster_instance" "this" {
  count              = var.instance_count
  identifier         = "${var.name}-${count.index}"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class
  tags               = var.tags
}
