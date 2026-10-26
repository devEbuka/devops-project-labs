output "bucket_arn" {
  value       = aws_s3_bucket.deployment_artifacts.arn
  description = "ARN of the S3 deployment artifacts bucket"
}

output "bucket_name" {
  value = aws_s3_bucket.deployment_artifacts.id
  description = "Name of the S3 deployment artifacts bucket"
}