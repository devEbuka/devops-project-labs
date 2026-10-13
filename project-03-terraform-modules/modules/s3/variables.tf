variable "bucket_name" {
  description = "The globally unique name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "The environment associated with the bucket"
  type        = string
}