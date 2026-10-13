output "vpc_id" {
  description = "The ID of our development VPC"
  value       = module.development_vpc.vpc_id
}

output "public_subnet_id" {
  description = "The ID of our public subnet"
  value       = module.development_vpc.public_subnet_id
}

output "internet_gateway_id" {
  description = "The ID of our Internet Gateway"
  value       = module.development_vpc.internet_gateway_id
}

output "public_route_table_id" {
  description = "The ID of our public route table"
  value       = module.development_vpc.public_route_table_id
}