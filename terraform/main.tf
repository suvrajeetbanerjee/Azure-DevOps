terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# ───────────────────────────────────────────────
# VPC
# ───────────────────────────────────────────────
resource "aws_vpc" "project_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "project-vpc"
  }
}

# ───────────────────────────────────────────────
# Public Subnet
# ───────────────────────────────────────────────
resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.project_vpc.id
  cidr_block              = "10.0.128.0/20"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "project-subnet-public1-ap-south-1a"
  }
}

# ───────────────────────────────────────────────
# Internet Gateway
# ───────────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "project-igw"
  }
}

# ───────────────────────────────────────────────
# Public Route Table + Default Route
# ───────────────────────────────────────────────
resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "project-rtb-public"
  }
}

resource "aws_route_table_association" "rtb_assoc_public_1a" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rtb.id
}

# ───────────────────────────────────────────────
# Security Group (SSH + HTTP)
# ───────────────────────────────────────────────
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "Allow SSH & HTTP"
  vpc_id      = aws_vpc.project_vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow All Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-sg"
  }
}

# ───────────────────────────────────────────────
# EC2 Instance (Ubuntu 24.04 LTS — YOUR AMI)
# ───────────────────────────────────────────────
resource "aws_instance" "ubuntu_nginx_vm" {
  ami                         = "ami-02b8269d5e85954ef" # Ubuntu 24.04 x86_64 as you provided
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1a.id
  vpc_security_group_ids      = [aws_security_group.nginx_sg.id]
  associate_public_ip_address = true
  key_name                    = "suvrajeet.key"

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    iops        = 3000
    encrypted   = false
  }

  tags = {
    Name = "ubuntu-nginx-vm"
  }
}

# ───────────────────────────────────────────────
# Output
# ───────────────────────────────────────────────
output "ec2_public_ip" {
  value = aws_instance.ubuntu_nginx_vm.public_ip
}
