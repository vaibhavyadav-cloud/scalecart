variable "repository_names" {
  description = "One per service - see the image list in docs/04-docker-optimization.md"
  type        = list(string)
  default = [
    "auth-service",
    "product-service",
    "cart-service",
    "order-service",
    "payment-service",
    "notification-service",
    "frontend",
  ]
}

variable "tags" {
  type    = map(string)
  default = {}
}
