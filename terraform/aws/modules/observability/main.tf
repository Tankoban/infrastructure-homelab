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
  # checkov:skip=CKV_AWS_158:AWS-managed encryption at rest is sufficient for this homelab; customer-managed KMS is deferred.
  # checkov:skip=CKV_AWS_338:Seven-day retention is intentional for disposable homelab telemetry; production retention would be longer.
  name              = "/homelab/ec2/syslog"
  retention_in_days = 7

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}

resource "aws_cloudwatch_log_group" "nginx" {
  # checkov:skip=CKV_AWS_158:AWS-managed encryption at rest is sufficient for this homelab; customer-managed KMS is deferred.
  # checkov:skip=CKV_AWS_338:Seven-day retention is intentional for disposable homelab telemetry; production retention would be longer.
  name              = "/homelab/nginx"
  retention_in_days = 7

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Observability"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "homelab-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "homelab-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]

        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  # checkov:skip=CKV_AWS_158:AWS-managed encryption at rest is sufficient for this homelab; customer-managed KMS is deferred.
  # checkov:skip=CKV_AWS_338:Seven-day retention is intentional for disposable homelab telemetry; production retention would be longer.

  name              = "/homelab/vpc/flow-logs"
  retention_in_days = 7

  tags = {
    Name = "homelab-vpc-flow-logs"
  }
}

resource "aws_flow_log" "homelab" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = var.vpc_id

  tags = {
    Name = "homelab-vpc-flow-log"
  }
}
