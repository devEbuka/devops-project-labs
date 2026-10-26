output "jwt_secret_arn" {
  value       = aws_secretsmanager_secret.jwt_auth.arn
  description = "The ARN of the JWT signing secret."
}