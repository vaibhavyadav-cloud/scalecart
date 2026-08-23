output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cloudfront_domain" {
  value = module.frontend_cdn.distribution_domain_name
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "irsa_role_arns" {
  value = module.iam.service_role_arns
}

output "kafka_bootstrap_brokers" {
  value     = module.kafka.bootstrap_brokers_tls
  sensitive = true
}
