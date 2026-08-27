resource "aws_vpc" "homelab" {
  # checkov:skip=CKV2_AWS_11:VPC Flow Logs are enabled through the observability module using this VPC's exported ID; Checkov does not resolve the cross-module relationship.

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "tf-homelab-vpc"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.homelab.id

  tags = {
    Name = "homelab-default-sg"
  }
}

resource "aws_subnet" "public_1" {
  # checkov:skip=CKV_AWS_130:Public IP assignment is intentional for the current homelab architecture; private compute is planned for Phase VIII.
  vpc_id                  = aws_vpc.homelab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "tf-homelab-public-1"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.homelab.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name        = "tf-homelab-private-1"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "homelab" {
  vpc_id = aws_vpc.homelab.id

  tags = {
    Name        = "tf-homelab-igw"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.homelab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.homelab.id
  }

  tags = {
    Name        = "tf-homelab-public-rt"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}
