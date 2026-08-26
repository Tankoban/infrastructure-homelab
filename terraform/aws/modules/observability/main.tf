resource "aws_iam_role" "cloudwatch_agent" {
  name = "homelab-cloudwatch-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name      = "homelab-cloudwatch-agent-role"
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cloudwatch_agent" {
  name = "homelab-cloudwatch-agent-profile"
  role = aws_iam_role.cloudwatch_agent.name
}

resource "aws_cloudwatch_log_group" "syslog" {
  name              = "/homelab/ec2/syslog"
  retention_in_days = 7

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/homelab/nginx"
  retention_in_days = 7

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}
