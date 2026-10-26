data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "networking" {
  source                 = "../../modules/networking"
  vpc_cidr               = "10.0.0.0/16"
  vpc_name               = "inventory-api-vpc-dev"
  environment            = "dev"
  public_subnet_cidr     = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones     = ["us-west-1a", "us-west-1c"]
  private_subnet_cidr    = ["10.0.11.0/24", "10.0.12.0/24"]
  private_subnet_db_cidr = ["10.0.21.0/24", "10.0.22.0/24"]
}

module "security_groups" {
  source      = "../../modules/security-groups"
  vpc_id      = module.networking.vpc_id
  environment = "dev"
  name        = "inventory-api"
}

module "secrets" {
  source      = "../../modules/secrets-manager"
  environment = "dev"
}

module "iam" {
  source                = "../../modules/iam"
  environment           = "dev"
  db_secret_arn         = module.database.db_secret_arn
  jwt_secret_arn        = module.secrets.jwt_secret_arn
  deployment_bucket_arn = module.deployment_storage.bucket_arn
}

module "database" {
  source                = "../../modules/database"
  environment           = "dev"
  private_subnet_db_ids = module.networking.private_db_subnet_ids
  db_security_group_id  = module.security_groups.db_security_group_id
}

module "compute" {
  source               = "../../modules/compute"
  environment          = "dev"
  ami_id               = "ami-08ded8f0046ffc971"
  instance_type        = "t3.micro"
  subnet_id            = module.networking.private_subnet_ids[0]
  security_group_ids   = [module.security_groups.app_security_group_id]
  iam_instance_profile = module.iam.ec2_instance_profile_name
  aws_account_id       = data.aws_caller_identity.current.account_id
  aws_region           = data.aws_region.current.region
  ecr_repository_url   = module.ecr.ecr_repository_url
}

module "ecr" {
  source      = "../../modules/ecr"
  environment = "dev"
}

module "deployment_storage" {
  source      = "../../modules/deployment_storage"
  environment = "dev"
  bucket_name = "inventory-api-deploy-artifacts-007"
}

module "alb" {
  source = "../../modules/alb"

  environment           = "dev"
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  instance_id           = module.compute.instance_id
}