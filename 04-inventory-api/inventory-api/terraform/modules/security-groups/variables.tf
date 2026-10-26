variable "name" {
  description = "Name of the security group"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the security group will be created"
  type        = string
}

variable "environment" {
  description = "The environment for the security group (e.g., dev, prod)"
  type        = string
}