variable "environment" {
  description = "The environment for which the IAM role is being created (e.g., dev, staging, prod)."
  type        = string
}

variable "db_secret_arn" {
  description = "The ARN of the secret in AWS Secrets Manager that contains the database credentials."
  type        = string
}

variable "jwt_secret_arn" {
  description = "The ARN of the secret in AWS Secrets Manager that contains the JWT signing secret."
  type        = string
}

variable "deployment_bucket_arn" {
  description = "ARN of the S3 bucket containing deployment artifacts"
  type = string
}