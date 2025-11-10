output "frontend_public_ip" {
  description = "Public IP address of frontend EC2"
  value       = aws_instance.frontend.public_ip
}

output "frontend_dns" {
  description = "Public DNS of frontend EC2"
  value       = aws_instance.frontend.public_dns
}

output "backend_private_ip" {
  description = "Private IP address of backend EC2"
  value       = aws_instance.backend.private_ip
}

output "rds_endpoint" {
  description = "RDS endpoint (hostname:port)"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_address" {
  description = "RDS hostname only"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.mysql.port
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}