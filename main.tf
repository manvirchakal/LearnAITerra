# Cognito User Pool
resource "aws_cognito_user_pool" "learnai_pool" {
  name = var.cognito_user_pool_name

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "learnai_client" {
  name         = "learnai-client"
  user_pool_id = aws_cognito_user_pool.learnai_pool.id

  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# S3 Bucket for textbooks
resource "aws_s3_bucket" "textbook_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "textbook_bucket_public_access" {
  bucket = aws_s3_bucket.textbook_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# EC2 Instance for running the application
resource "aws_instance" "learnai_app" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (adjust for your region)
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_name

  vpc_security_group_ids = [aws_security_group.learnai_sg.id]

  tags = {
    Name = "LearnAI-App-Server"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 git
              git clone https://github.com/manvirchakal/LearnAI /home/ec2-user/learnai
              EOF
}

# Security Group for EC2 instance
resource "aws_security_group" "learnai_sg" {
  name        = "learnai-security-group"
  description = "Security group for LearnAI application"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
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