variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  description = "Still 3 for subnet/AZ-count parity with prod (catches AZ-count-sensitive bugs early) even though node capacity itself is minimal"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
