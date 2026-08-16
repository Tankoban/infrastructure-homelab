data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_vpc" "homelab" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "tf-homelab-vpc"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.homelab.id
  cidr_block              = "10.20.10.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "tf-homelab-public-1"
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.homelab.id
  cidr_block        = "10.20.20.0/24"
  availability_zone = "us-east-2a"

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

resource "aws_security_group" "web" {
  name        = "tf-homelab-web-sg"
  description = "Security group for Terraform homelab web server"
  vpc_id      = aws_vpc.homelab.id

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

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = "homelab-ec2-key"

  user_data = file("${path.module}/user-data.sh")

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name        = "tf-homelab-ubuntu-web-01"
    Environment = "Lab"
    ManagedBy   = "Terraform"
    Purpose     = "IaC-Learning"
  }
}
