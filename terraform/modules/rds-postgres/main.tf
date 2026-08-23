# Instantiated 3 times (once each for auth, orders, payments - see
# terraform/envs/prod/main.tf) rather than one shared RDS instance with 3
# databases, so each service's database can be resized, patched, backed
# up, and failed over independently - the actual point of
# database-per-service (docs/03-databases-per-service.md). Paying for 3
# instances instead of 1 is the real cost of that isolation, accepted
# deliberately here.

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-rds-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
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
  special = false # avoid characters that need URL-encoding in a JDBC/connection-string DATABASE_URL
}

# The generated password is written to Secrets Manager, never to
# Terraform state's plaintext output or a .tf file - the External Secrets
# Operator (k8s/base/03-external-secrets.yaml) reads it from here at
# runtime. See docs/15-security-hardening.md.
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "scalecart/${var.name}/db-credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username     = var.master_username
    password     = random_password.master.result
    host         = aws_db_instance.this.address
    port         = 5432
    database_url = "postgresql://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/${var.database_name}"
  })
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 4 # storage autoscaling ceiling - grows with data, no manual resize needed
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false

  multi_az                     = var.multi_az
  backup_retention_period      = var.backup_retention_days
  backup_window                = "03:00-04:00" # off-peak for this platform's assumed traffic pattern
  maintenance_window           = "mon:04:30-mon:05:30"
  deletion_protection          = var.multi_az # only hard-guard against accidental deletion in envs where multi_az implies "this is prod-like"
  skip_final_snapshot          = !var.multi_az
  final_snapshot_identifier    = var.multi_az ? "${var.name}-final-snapshot" : null
  performance_insights_enabled = true

  tags = var.tags
}

# Read replicas - promoted from 0 in dev to N in prod when read traffic
# on a specific service's DB starts dominating write traffic. See the
# capacity-planning math in docs/14-scaling-to-1m-users.md for exactly
# which service (order-service's order-history reads) hits this first.
resource "aws_db_instance" "read_replica" {
  count               = var.read_replica_count
  identifier          = "${var.name}-replica-${count.index}"
  replicate_source_db = aws_db_instance.this.identifier
  instance_class      = var.instance_class
  publicly_accessible = false
  storage_encrypted   = true
  tags                = var.tags
}
