output "endpoint" {
  value = aws_docdb_cluster.this.endpoint
}

output "secret_arn" {
  value = aws_secretsmanager_secret.credentials.arn
}

output "security_group_id" {
  value = aws_security_group.this.id
}
