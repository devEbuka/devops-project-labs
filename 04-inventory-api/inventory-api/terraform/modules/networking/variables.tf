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
  type        = list(string)
}

variable "private_subnet_cidr" {
  description = "The IPv4 CIDR block for the private subnet"
  type        = list(string)
}

variable "private_subnet_db_cidr" {
  description = "The IPv4 CIDR block for the private database subnet"
  type        = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "nat_gateway_count" {
  description = "The number of NAT Gateways to create"
  type        = number
  default     = 1
}