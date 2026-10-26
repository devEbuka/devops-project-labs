output "deployment_bucket_name" {
  description = "S3 bucket used to store deployment artifacts"
  value       = module.deployment_storage.bucket_name
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.compute.instance_id
}

output "db_secret_arn" {
  description = "ARN of the RDS-managed database secret"
  value       = module.database.db_secret_arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = module.secrets.jwt_secret_arn
}

output "db_host" {
  description = "RDS PostgreSQL hostname"
  value       = module.database.db_host
}

output "alb_dns_name" {
  description = "Public endpoint for the Inventory API"
  value       = module.alb.alb_dns_name
}