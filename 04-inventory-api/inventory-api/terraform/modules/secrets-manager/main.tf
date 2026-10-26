resource "aws_secretsmanager_secret" "jwt_auth" {
  name        = "${var.environment}-inventory-api-jwt-secret"
  description = "JWT signing secret for ${var.environment} environment"

  # lifecycle {
  #   prevent_destroy = true
  # }
}