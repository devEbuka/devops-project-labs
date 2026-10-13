variable "vpc_cidr" {
  description = "The IPV4 CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "The name assigned to the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "The IPv4 CIDR block for the public subnet"
  type        = string
}