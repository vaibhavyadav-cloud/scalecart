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

variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "instance_count" {
  description = "1 writer + N readers. DocumentDB replicas serve reads AND stand ready for automatic failover - unlike RDS read replicas, they share the same underlying cluster storage."
  type        = number
  default     = 2
}

variable "master_username" {
  type    = string
  default = "scalecart"
}

variable "tags" {
  type    = map(string)
  default = {}
}
