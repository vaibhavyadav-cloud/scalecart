variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  type = list(string)
}

variable "node_type" {
  type    = string
  default = "cache.t4g.medium"
}

variable "num_cache_nodes" {
  description = "Replica count behind the primary - 1 replica minimum in prod for automatic failover"
  type        = number
  default     = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
