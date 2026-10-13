variable "ami_id" {
  description = "The AMI ID used to launch the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
}

variable "subnet_id" {
  description = "The subnet where the EC2 instance will be launched"
  type        = string
}

variable "instance_name" {
  description = "The name assigned to the EC2 instance"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the security group will be created"
  type        = string
}

variable "iam_instance_profile" {
  description = "The IAM instance profile to associate with the EC2 instance"
  type        = string
  default     = null
}