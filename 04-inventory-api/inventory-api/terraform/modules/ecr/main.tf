resource "aws_ecr_repository" "inventory_api" {
  name = "${var.environment}-inventory_api"
  force_delete = true
}
