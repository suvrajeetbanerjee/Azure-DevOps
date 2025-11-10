# ==================== TERRAFORM CONFIGURATION ====================
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==================== AWS PROVIDER ====================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "BookReview"
      Environment = var.environment
      CreatedBy   = "Terraform"
    }
  }
}

# ==================== DATA SOURCES ====================
data "aws_availability_zones" "available" {
  state = "available"
}

# ==================== VPC ====================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "book-review-vpc"
  }
}

# ==================== INTERNET GATEWAY ====================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "book-review-igw"
  }
}

# ==================== ELASTIC IP FOR NAT ====================
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "book-review-nat-eip"
  }
  depends_on = [aws_internet_gateway.main]
}

# ==================== NAT GATEWAY ====================
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "book-review-nat"
  }
  depends_on = [aws_internet_gateway.main]
}

# ==================== PUBLIC SUBNET (Frontend) ====================
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "book-review-public-subnet"
    Type = "Public"
  }
}

# ==================== PRIVATE SUBNET 1 (Backend) ====================
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "book-review-private-subnet-1"
    Type = "Private"
  }
}

# ==================== PRIVATE SUBNET 2 (RDS) ====================
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "book-review-private-subnet-2"
    Type = "Private"
  }
}

# ==================== PUBLIC ROUTE TABLE ====================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name = "book-review-public-rtb"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ==================== PRIVATE ROUTE TABLE ====================
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "book-review-private-rtb"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ==================== SECURITY GROUPS ====================

# Frontend Security Group
resource "aws_security_group" "frontend" {
  name_prefix = "book-review-frontend-"
  description = "Security group for frontend web server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "book-review-frontend-sg"
  }
}

# Backend Security Group
resource "aws_security_group" "backend" {
  name_prefix = "book-review-backend-"
  description = "Security group for backend API server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from public subnet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Flask API port"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "book-review-backend-sg"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name_prefix = "book-review-rds-"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from backend"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "book-review-rds-sg"
  }
}

# ==================== EC2 INSTANCES ====================

# Frontend EC2 (Public Subnet)
resource "aws_instance" "frontend" {
  ami                    = var.ubuntu_ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  key_name               = "suvrajeet"

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  associate_public_ip_address = true

  tags = {
    Name = "book-review-frontend"
    Role = "Frontend"
  }
}

# Backend EC2 (Private Subnet)
resource "aws_instance" "backend" {
  ami                    = var.ubuntu_ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = "suvrajeet"

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "book-review-backend"
    Role = "Backend"
  }
}

# ==================== RDS SUBNET GROUP ====================
resource "aws_db_subnet_group" "main" {
  name_prefix = "book-review-"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "book-review-db-subnet-group"
  }
}

# ==================== RDS MYSQL INSTANCE ====================
resource "aws_db_instance" "mysql" {
  identifier            = "book-review-mysql"
  engine                = "mysql"
  engine_version        = "8.0.35"
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  storage_type          = "gp3"

  db_name             = var.db_name
  username            = var.db_username
  password            = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible       = false
  multi_az                  = false
  skip_final_snapshot       = true
  backup_retention_period   = 7

  tags = {
    Name = "book-review-mysql"
  }

  depends_on = [aws_security_group.rds]
}