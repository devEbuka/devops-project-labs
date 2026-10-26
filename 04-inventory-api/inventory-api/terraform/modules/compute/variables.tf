variable "ami_id" {
  description = "The ID of the AMI to use for the EC2 instance."
  type        = string
}

variable "instance_type" {
  description = "The type of instance to use for the EC2 instance."
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "The ID of the subnet to launch the EC2 instance in."
  type        = string
}

variable "security_group_ids" {
  description = "The IDs of the security groups to associate with the EC2 instance."
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "The name of the IAM instance profile to associate with the EC2 instance."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID where the resources will be created."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the resources will be created."
  type        = string
}

variable "ecr_repository_url" {
  description = "The URL of the ECR repository."
  type        = string
}