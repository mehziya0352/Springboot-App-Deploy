# ----------------------------
# Outputs
# ----------------------------
output "app_public_ip" {
  description = "Public IP of the builder instance (SSH here to run Ansible)"
  value       = aws_instance.builder.public_ip
}

output "rds_endpoint" {
  description = "RDS endpoint (connect from app servers inside VPC)"
  value       = aws_db_instance.mysql.endpoint
}
