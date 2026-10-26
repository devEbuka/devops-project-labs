// define an AWS EC2 instance resource
resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile        = var.iam_instance_profile
  associate_public_ip_address = false
  user_data = templatefile("${path.module}/data.sh", {
    aws_account_id     = var.aws_account_id
    aws_region         = var.aws_region
    ecr_repository_url = var.ecr_repository_url
  })

  tags = {
    Name = "${var.environment}-inventory-api-app"
  }
}
