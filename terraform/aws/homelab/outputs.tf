output "vpc_id" {
  description = "Terraform homelab VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "Terraform public subnet ID"
  value       = module.networking.public_subnet_id
}

output "private_subnet_id" {
  description = "Terraform private subnet ID"
  value       = module.networking.private_subnet_id
}

output "security_group_id" {
  description = "Terraform web security group ID"
  value       = module.security.security_group_id
}

output "instance_id" {
  description = "Terraform EC2 instance ID"
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "Terraform EC2 public IPv4 address"
  value       = module.compute.public_ip
}

output "instance_private_ip" {
  description = "Terraform EC2 private IPv4 address"
  value       = module.compute.private_ip
}

output "app1_url" {
  description = "App1 URL"
  value       = "http://${module.compute.public_ip}/app1/"
}

output "app2_url" {
  description = "App2 URL"
  value       = "http://${module.compute.public_ip}/app2/"
}
