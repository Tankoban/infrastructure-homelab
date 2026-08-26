output "instance_profile_name" {
  description = "Name of the IAM instance profile used by EC2 for CloudWatch access"
  value       = aws_iam_instance_profile.cloudwatch_agent.name
}
