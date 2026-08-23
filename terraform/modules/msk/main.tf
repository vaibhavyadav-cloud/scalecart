# The production-managed alternative to the in-cluster Strimzi Kafka
# deployment (k8s/kafka/01-kafka-cluster.yaml) used for the K8s/Helm demo
# path. This module is deliberately NOT wired into terraform/envs/dev
# (see envs/dev/main.tf) - dev/demo use Strimzi so the whole platform
# stands up on a personal AWS account or even a local kind cluster without
# needing MSK's cost or setup time. terraform/envs/prod instantiates this
# module instead. Every service's KAFKA_BOOTSTRAP_SERVERS is just a
# connection string either way - see docs/08-kafka-event-driven.md.
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-msk-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Kafka broker (plaintext within the VPC - TLS is used for anything crossing a trust boundary; see docs/15-security-hardening.md)"
    from_port       = 9092
    to_port         = 9094
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

resource "aws_msk_cluster" "this" {
  cluster_name           = var.name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.broker_count

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.private_subnet_ids
    security_groups = [aws_security_group.this.id]
    storage_info {
      ebs_storage_info {
        volume_size = var.broker_ebs_volume_gb
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  # min.insync.replicas=2 + a 3-broker cluster is what backs order-service's
  # acks=all producer config (application.yml) with a real durability
  # guarantee - a write isn't acknowledged until 2 of 3 brokers have it.
  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  tags = var.tags
}

resource "aws_msk_configuration" "this" {
  name              = "${var.name}-config"
  kafka_versions    = [var.kafka_version]
  server_properties = <<-PROPERTIES
    auto.create.topics.enable=false
    default.replication.factor=3
    min.insync.replicas=2
    num.partitions=6
  PROPERTIES
}
