variable "instance_id" {
  description = "EC2 instance ID to monitor"
  type        = string
}

variable "aws_region" {
  description = "AWS region containing the monitored resources"
  type        = string
  default     = "us-east-2"
}
