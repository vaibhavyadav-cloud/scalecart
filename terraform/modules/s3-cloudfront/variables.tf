variable "name" {
  type = string
}

variable "domain_name" {
  description = "e.g. scalecart.example.com - must match the Istio Gateway's host if the mesh sits behind this CDN, or be the sole public entry point if the frontend bypasses the mesh entirely (see docs/01-architecture.md)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "Must be issued in us-east-1 regardless of the stack's region - a hard CloudFront requirement"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
