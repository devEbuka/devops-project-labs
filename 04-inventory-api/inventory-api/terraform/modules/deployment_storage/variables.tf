variable "environment" {
  description = "Environment for the deployment artifact"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket used to store deployment artifacts"
  type        = string
}