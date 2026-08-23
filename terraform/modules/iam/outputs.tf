output "service_role_arns" {
  value = { for k, v in aws_iam_role.service : k => v.arn }
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}

output "lb_controller_role_arn" {
  value = aws_iam_role.lb_controller.arn
}
