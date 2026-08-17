variable "vpc_id" {
  description = "ID of the VPC where the security group will be created"
  type        = string
}

variable "admin_cidr" {
  description = "IPv4 CIDR allowed to SSH into the lab EC2 instance"
  type        = string
}
