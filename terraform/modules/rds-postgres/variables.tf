variable "name" {
  description = "e.g. scalecart-prod-auth - instantiated once per owning service, see terraform/envs/prod/main.tf"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach this DB on 5432 - normally just the EKS node group's SG"
  type        = list(string)
}

variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "allocated_storage" {
  type    = number
  default = 50
}

variable "multi_az" {
  description = "true for prod (automatic failover to a standby in another AZ), false for dev (cost)"
  type        = bool
  default     = true
}

variable "read_replica_count" {
  description = "0 in dev; see docs/14-scaling-to-1m-users.md for when this should be > 0 in prod"
  type        = number
  default     = 0
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "database_name" {
  type = string
}

variable "master_username" {
  type    = string
  default = "scalecart"
}

variable "tags" {
  type    = map(string)
  default = {}
}
