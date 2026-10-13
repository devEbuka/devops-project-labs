
resource "aws_security_group" "this" {
  name_prefix = "dev-ec2-sg-"
  description = "Security group for the EC2 instance"
  vpc_id      = var.vpc_id

  tags = {
    Name = "dev-ec2-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_ipv4" {
  security_group_id = aws_security_group.this.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow all outbound IPv4 traffic"
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true
  iam_instance_profile = var.iam_instance_profile

  tags = {
    Name = var.instance_name
  }
}