
resource "aws_security_group" "web" {
  # checkov:skip=CKV2_AWS_5:Security group is attached to EC2 through the root module and compute module variable; Checkov does not resolve this cross-module relationship
  # checkov:skip=CKV_AWS_260:Public HTTP is intentional during the current lab architecture; trusted HTTPS and TLS termination are planned for Phase IX.
  # checkov:skip=CKV_AWS_382:Unrestricted egress is temporarily required for package installation, container pulls, updates, and AWS service access; tighter egress controls are deferred to the private architecture phase.
  name        = "tf-homelab-web-sg"
  description = "Security group for Terraform homelab web server"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "tf-homelab-web-sg"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

