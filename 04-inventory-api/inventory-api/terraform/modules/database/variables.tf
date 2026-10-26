variable "environment" {
  description = "The deployment environment for the database resources (e.g., dev, staging, prod)."
}

variable "private_subnet_db_ids" {
  description = "List of private subnet IDs for the database."
  type        = list(string)
}

variable "db_security_group_id" {
  description = "The ID of the security group to associate with the database instance."
  type        = string
}