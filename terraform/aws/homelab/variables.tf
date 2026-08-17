variable "admin_cidr" {
  description = "IPv4 CIDR allowed to SSH into the lab EC2 instance"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the homelab VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public homelab subnet"
  type        = string
  default     = "10.20.10.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private homelab subnet"
  type        = string
  default     = "10.20.20.0/24"
}

variable "availability_zone" {
  description = "Availability Zone used by the homelab"
  type        = string
  default     = "us-east-2a"
}
