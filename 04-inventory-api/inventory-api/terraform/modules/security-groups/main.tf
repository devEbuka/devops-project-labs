//Load balancer security group
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

//HTTP ingress rules for ALB security group
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.alb.id
}

//HTTPS ingress rules for ALB security group
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.alb.id
}

//App security group
resource "aws_security_group" "app" {
  name        = "${var.environment}-app-sg"
  description = "Security group for application instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-app-sg"
  }
}

//Egress rules for ALB to application security group
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
}

//Ingress rules for application security group from ALB
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
}

//Database security group
resource "aws_security_group" "db" {
  name        = "${var.environment}-db-sg"
  description = "Security group for database instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_https" {
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "app_http_outbound" {
  security_group_id = aws_security_group.app.id

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"

  description = "Allow outbound HTTP for package repositories"
}