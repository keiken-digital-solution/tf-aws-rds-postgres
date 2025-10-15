output "db_instance_id" {
  value       = aws_db_instance.this.id
  description = "RDS DB instance identifier."
}

output "endpoint" {
  value       = aws_db_instance.this.address
  description = "RDS endpoint address."
}

output "port" {
  value       = aws_db_instance.this.port
  description = "RDS port."
}

output "database_name" {
  value       = aws_db_instance.this.db_name
  description = "Initial database name."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "Security group ID attached to the DB."
}

output "subnet_group_name" {
  value       = aws_db_subnet_group.this.name
  description = "DB subnet group name."
}

output "parameter_group_name" {
  value       = aws_db_parameter_group.this.name
  description = "DB parameter group name."
}

output "secret_arn" {
  value       = aws_secretsmanager_secret.this.arn
  description = "ARN of the Secrets Manager secret with credentials (always managed)."
}

