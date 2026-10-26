resource "aws_db_subnet_group" "db" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_db_ids


  tags = {
    Name = "${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier                  = "${var.environment}-db-instance"
  engine                      = "postgres"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  db_subnet_group_name        = aws_db_subnet_group.db.name
  vpc_security_group_ids      = [var.db_security_group_id]
  publicly_accessible         = false
  username                    = "inventory_admin"
  manage_master_user_password = true
  multi_az                    = false
  skip_final_snapshot         = true
  deletion_protection         = false
  db_name                     = "inventory_db"
  storage_encrypted           = true
  backup_retention_period     = 0
}