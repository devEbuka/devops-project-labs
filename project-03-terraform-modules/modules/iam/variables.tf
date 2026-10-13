variable "role_name" {
  description = "The name of the IAM role"
  type        = string
}

variable "environment" {
  description = "The environment associated with the IAM role"
  type        = string
}

variable "bucket_arn" {
  description = "The ARN of the S3 bucket the role can access"
  type        = string
}