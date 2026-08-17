output "instance_id" {
  description = "ID of the homelab EC2 instance"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IPv4 address of the homelab EC2 instance"
  value       = aws_instance.web.public_ip
}

output "private_ip" {
  description = "Private IPv4 address of the homelab EC2 instance"
  value       = aws_instance.web.private_ip
}
