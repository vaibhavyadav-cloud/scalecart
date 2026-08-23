variable "name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  description = "Without the https:// prefix - see eks module's output"
  type        = string
}

variable "service_secret_arns" {
  description = "Map of service name -> Secrets Manager ARN it needs read access to, e.g. { auth-service = module.auth_db.secret_arn }"
  type        = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
