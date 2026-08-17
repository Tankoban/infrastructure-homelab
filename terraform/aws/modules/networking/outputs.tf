output "vpc_id" {
  description = "ID of the homelab VPC"
  value       = aws_vpc.homelab.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_1.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private_1.id
}
