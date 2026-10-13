module "development_vpc" {
  source             = "./modules/vpc"
  vpc_cidr           = "10.0.0.0/16"
  vpc_name           = "dev-vpc"
  public_subnet_cidr = "10.0.1.0/24"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "web_server" {
  source = "./modules/ec2"

  ami_id        = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = module.development_vpc.public_subnet_id
  vpc_id        = module.development_vpc.vpc_id
  instance_name = "dev-web-server"
  iam_instance_profile = module.ec2_role.instance_profile_name
}

module "storage_bucket" {
  source = "./modules/s3"

  bucket_name = "dev-ebuka-terraform-lab-20261013"
  environment = "development"
}

module "ec2_role" {
  source = "./modules/iam"

  role_name   = "dev-ec2-s3-role"
  environment = "development"
  bucket_arn  = module.storage_bucket.bucket_arn
}

output "web_server_instance_id" {
  description = "The ID of our EC2 instance"
  value       = module.web_server.instance_id
}

output "web_server_public_ip" {
  description = "The public IP address of our EC2 instance"
  value       = module.web_server.public_ip
}

output "web_server_private_ip" {
  description = "The private IP address of our EC2 instance"
  value       = module.web_server.private_ip
}

output "s3_bucket_id" {
  description = "The ID of the S3 bucket"
  value       = module.storage_bucket.bucket_id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = module.storage_bucket.bucket_arn
}
