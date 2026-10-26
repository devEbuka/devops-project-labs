terraform {
  backend "s3" {
    bucket       = "inventory-api-terraform-state-007"
    key          = "dev/terraform.tfstate"
    region       = "us-west-1"
    encrypt      = true
    use_lockfile = true
  }
}