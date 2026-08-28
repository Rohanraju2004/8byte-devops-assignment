variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "8byte-devops"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "IP address range for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "IP ranges for the public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
