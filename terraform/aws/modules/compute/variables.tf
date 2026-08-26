variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be deployed"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID attached to the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name used for SSH access"
  type        = string
  default     = "homelab-ec2-key"
}

variable "user_data" {
  description = "Bootstrap script supplied to the EC2 instance"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to the EC2 instance"
  type        = string
  default     = null
}
