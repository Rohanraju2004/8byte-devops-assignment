output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "db_endpoint" {
  description = "RDS connection endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master password"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}