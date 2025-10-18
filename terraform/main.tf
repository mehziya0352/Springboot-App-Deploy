terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ----------------------------
# Data sources
# ----------------------------
data "aws_availability_zones" "available" {}

# automatically fetch your current public IP (used for builder SSH)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
  # note: this will make plan/app depend on network access from where you run terraform
}

locals {
  public_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ----------------------------
# VPC
# ----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "petclinic-vpc"
  }
}

# ----------------------------
# Subnets
# ----------------------------
# Public subnet (builder)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "petclinic-public-subnet"
  }
}

# Private subnets for RDS (two AZs)
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "petclinic-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "petclinic-private-subnet-2"
  }
}

# ----------------------------
# Internet Gateway + Route Table
# ----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "petclinic-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "petclinic-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# ----------------------------
# Security Groups
# ----------------------------
# Builder SG - for SSH from your IP (only)
resource "aws_security_group" "builder_sg" {
  name        = "builder-sg"
  description = "Allow SSH from controller IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.public_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "builder-sg" }
}

# App SG - used later by app servers; allow outbound to RDS
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "App servers SG (allow outbound to RDS)"
  vpc_id      = aws_vpc.main.id

  # Allow inbound from ALB later; keep minimal now
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # change to ALB SG later for production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "app-sg" }
}

# RDS SG - allow MySQL from app_sg and builder_sg only
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "RDS security group - only allow app and builder"
  vpc_id      = aws_vpc.main.id

  ingress {
    description               = "MySQL from app servers"
    from_port                 = 3306
    to_port                   = 3306
    protocol                  = "tcp"
    security_groups           = [aws_security_group.app_sg.id]
  }

  ingress {
    description               = "MySQL from builder for setup"
    from_port                 = 3306
    to_port                   = 3306
    protocol                  = "tcp"
    security_groups           = [aws_security_group.builder_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-sg" }
}

# ----------------------------
# EC2 Builder Instance (public subnet)
# ----------------------------
resource "aws_instance" "builder" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.builder_sg.id, aws_security_group.app_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "petclinic-builder"
    Role = "builder"
    Env  = "dev"
  }
}

# ----------------------------
# DB Subnet Group (private subnets)
# ----------------------------
resource "aws_db_subnet_group" "mysql_subnets" {
  name       = "mysql-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  tags = { Name = "mysql-subnet-group" }
}

# ----------------------------
# RDS MySQL (Multi-AZ, private)
# ----------------------------
resource "aws_db_instance" "mysql" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0.39"           # works in us-east-1; adjust if needed
  instance_class         = "db.t3.medium"
  name                   = var.db_name
  username               = var.db_user
  password               = var.db_password
  multi_az               = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.mysql_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name = "petclinic-rds"
  }
}

# ----------------------------
# Outputs
# ----------------------------
output "builder_public_ip" {
  description = "Public IP of the builder instance (SSH here to run Ansible)"
  value       = aws_instance.builder.public_ip
}

output "rds_endpoint" {
  description = "RDS endpoint (connect from app servers inside VPC)"
  value       = aws_db_instance.mysql.endpoint
}
