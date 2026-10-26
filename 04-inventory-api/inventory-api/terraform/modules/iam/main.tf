//Trust policy for EC2 to assume the role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

// Create the IAM role for EC2 that assumes the Trust policy document
resource "aws_iam_role" "ec2_role" {
  name               = "${var.environment}-inventory-api-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

// Create an instance profile for the EC2 role
resource "aws_iam_instance_profile" "app" {
  name = "${var.environment}-inventory-api-profile"
  role = aws_iam_role.ec2_role.name
}

// Attach the AmazonEC2ContainerRegistryPullOnly policy to the EC2 role
resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

// Create a custom IAM permission policy to allow access to the database secret in AWS Secrets Manager
data "aws_iam_policy_document" "db_secret_access" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [var.db_secret_arn, var.jwt_secret_arn]
  }
}

// Create the IAM inline policy for database secret access
resource "aws_iam_policy" "db_secret_access" {
  name   = "${var.environment}-db-secret-access"
  policy = data.aws_iam_policy_document.db_secret_access.json
}

// Attach the custom IAM policy to the EC2 role
resource "aws_iam_role_policy_attachment" "db_secret_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.db_secret_access.arn
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "deployment_artifacts_access" {
  statement {
    effect = "Allow"
    actions = ["s3:GetObject"]

    resources = [
      "${var.deployment_bucket_arn}/releases/*"
    ]
  }
}

resource "aws_iam_role_policy" "deployment_artifacts_access" {
  name = "${var.environment}-deployment-artifacts-access"
  role = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.deployment_artifacts_access.json
}
