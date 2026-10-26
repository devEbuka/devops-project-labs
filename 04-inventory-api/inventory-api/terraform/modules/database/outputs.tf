output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_port" {
  value = aws_db_instance.postgres.port
}

output "db_secret_arn" {
  value = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

output "db_host" {
  description = "RDS hostname without the port"
  value       = aws_db_instance.postgres.address
}