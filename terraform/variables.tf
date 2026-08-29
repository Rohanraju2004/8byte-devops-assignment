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

variable "private_subnet_cidrs" {
  description = "IP ranges for the private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 3000
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "appdb"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "github_repo" {
  description = "GitHub repository in owner/name format"
  type        = string
  default     = "Rohanraju2004/8byte-devops-assignment"
}
variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = "rohanraju84@gmail.com"
}

variable "db_instance_class" {
  description = "RDS instance size"
  type        = string
  default     = "db.t4g.micro"
}