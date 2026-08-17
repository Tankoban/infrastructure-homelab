output "security_group_id" {
  description = "ID of the homelab web security group"
  value       = aws_security_group.web.id
}
