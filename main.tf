# Creating a VPC
resource "aws_vpc" "vpc01_v1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc01_v1"
  }
}

# Creating a Public Subnet
resource "aws_subnet" "v1_public_subnet" {
  vpc_id                  = aws_vpc.vpc01_v1.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Assigns public IP to instances on launch
  tags = {
    Name = "v1_public_subnet"
  }
}

# Creating a Private Subnet
resource "aws_subnet" "v1_private_subnet" {
  vpc_id            = aws_vpc.vpc01_v1.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "v1_private_subnet"
  }
}

# Creating an Internet Gateway for the VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc01_v1.id

  tags = {
    Name = "main_igw"
  }
}

# Security Group for PostgreSQL Database
resource "aws_security_group" "sg_postgres" {
  name        = "sg_postgres"
  description = "Security group for PostgreSQL database"
  vpc_id      = aws_vpc.vpc01_v1.id

  # Allow inbound traffic on PostgreSQL port (5432)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust this for better security
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for SMS Instance
resource "aws_security_group" "SMS_instance" {
  name        = "sg_SMS_instance"
  description = "Security group for SMS instance"
  vpc_id      = aws_vpc.vpc01_v1.id

  # Allow inbound HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for Systems Manager (SSM)
resource "aws_iam_role" "ssm_role" {
  name = "SSMRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the SSM Managed Policy to the Role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance (SMS Instance) in Public Subnet
resource "aws_instance" "SMSInstance" {
  ami                    = "ami-023456789abcdef01" # Replace with your AMI ID
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.SMS_instance.id]
  iam_instance_profile   = aws_iam_role.ssm_role.name
  subnet_id              = aws_subnet.v1_public_subnet.id
  tags = {
    Name = "SMSInstance"
  }
}

# Creating an RDS Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.v1_private_subnet.id]

  tags = {
    Name = "db_subnet_group"
  }
}

# RDS PostgreSQL Database Instance
resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  max_allocated_storage  = 30
  db_name                = "main_db"
  engine                 = "postgres"
  identifier             = "MainDB"
  instance_class         = "db.t2.micro"
  username               = "your_username"
  password               = "your_password"
  storage_encrypted      = false
  parameter_group_name   = "default.postgres16"
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg_postgres.id]
  tags = {
    Name = "postgres_db"
  }
}

# Output for RDS Instance ID
output "db_instance_id" {
  value       = aws_db_instance.postgres.id
  description = "The ID of the DB instance"
}

# Output for SMS Instance ID
output "SMSInstance_id" {
  value       = aws_instance.SMSInstance.id
  description = "The ID of the SMS instance"
}
