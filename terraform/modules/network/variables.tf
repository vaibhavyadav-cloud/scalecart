variable "name" {
  description = "Prefix for every resource this module creates, e.g. scalecart-prod"
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "3 AZs minimum - EKS control plane and this platform's topologySpreadConstraints both assume multi-AZ (see docs/06-kubernetes-advanced.md)"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
