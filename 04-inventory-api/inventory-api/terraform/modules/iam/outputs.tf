//Expose the ARN of the EC2 role and the name of the instance profile for use in other modules or resources.
output "ec2_role_arn" {
  value = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.app.name
}