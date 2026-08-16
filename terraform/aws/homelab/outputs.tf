output "vpc_id" {
  description = "Terraform homelab VPC ID"
  value       = aws_vpc.homelab.id
}

output "public_subnet_id" {
  description = "Terraform public subnet ID"
  value       = aws_subnet.public_1.id
}

output "private_subnet_id" {
  description = "Terraform private subnet ID"
  value       = aws_subnet.private_1.id
}

output "security_group_id" {
  description = "Terraform web security group ID"
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "Terraform EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Terraform EC2 public IPv4 address"
  value       = aws_instance.web.public_ip
}

output "instance_private_ip" {
  description = "Terraform EC2 private IPv4 address"
  value       = aws_instance.web.private_ip
}

output "app1_url" {
  description = "App1 URL"
  value       = "http://${aws_instance.web.public_ip}/app1/"
}

output "app2_url" {
  description = "App2 URL"
  value       = "http://${aws_instance.web.public_ip}/app2/"
}
