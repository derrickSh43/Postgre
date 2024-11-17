resource "aws_vpc" "vpc01_v1" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "vpc01_v1"
    }
}
resource "aws_subnet" "v1_public_subnet" {
    vpc_id = aws_vpc.vpc01_v1.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
        Name: "v1pu"
    }
}


resource "aws_subnet" "v1_private_subnet" {
    vpc_id = aws_vpc.vpc01_v1.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name: "v1pr"
    }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc01_v1.id

  tags = {
    Name = "main"
  }
}

resource "aws_instance" "SMSInstance" {
    ami           = "ami-023456789abcdef01"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.sg_postgres.id]
    iam_instance_profile = aws_iam_role.ssm_role.name
    subnet_id      = aws_subnet.v1_public_subnet.id
    tags = {
        Name = "SMSInstance"
    }
}

resource "aws_db_instance" "postgres" {
  allocated_storage = 20
  max_allocated_storage = 30
  db_name = "main_db"
  engine = "postgres"
  identifier = "MainDB"
  instance_class = "db.t2.micro"
  username = "your_username"
  password = "your_password"
  storage_encrypted = false
  parameter_group_name = "default.postgres16"
  skip_final_snapshot = true

  db_subnet_group_name = aws_subnet.v1_private_subnet

}

resource "aws_security_group" "sg_postgres" {
    name        = "sg_postgres"
    description = "Security group for PostgreSQL database"
    vpc_id      = aws_vpc.vpc01_v1.id

    ingress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "SMS_instance" {
    name        = "SMS_instance"
    description = "Security group for SMS instance"
    vpc_id      = aws_vpc.vpc01_v1.id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

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

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


output "db_instance_id" {
    value = aws_db_instance.postgres.id
    description = "The ID of the DB instance"
}

output "SMSInstance" {
    value = aws_instance.SMS_instance.id
    description = "The ID of the SMS instance"
}