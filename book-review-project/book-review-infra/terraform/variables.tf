variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "ubuntu_ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID for ap-south-1"
  type        = string
  default     = "ami-02b8269d5e85954ef"
}

variable "instance_type" {
  description = "EC2 instance type (free tier: t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 8
}

variable "rds_instance_class" {
  description = "RDS instance class (free tier: db.t2.micro)"
  type        = string
  default     = "db.t2.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB (free tier: 20GB)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "bookdb"
}

variable "db_username" {
  description = "Database admin username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

variable "ssh_cidr" {
  description = "CIDR block for SSH access to frontend"
  type        = string
  default     = "0.0.0.0/0"
}