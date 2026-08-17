variable "vpc_cidr" {
  description = "CIDR block for the homelab VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone used by the homelab subnets"
  type        = string
}
