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

# S3 Bucket for textbooks (knowledge base)
resource "aws_s3_bucket" "textbook_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_versioning" "textbook_bucket_versioning" {
  bucket = aws_s3_bucket.textbook_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "textbook_bucket_public_access" {
  bucket = aws_s3_bucket.textbook_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for Bedrock to access S3
resource "aws_iam_role" "bedrock_s3_access" {
  name = "bedrock-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_s3_access_policy" {
  name = "bedrock-s3-access-policy"
  role = aws_iam_role.bedrock_s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.textbook_bucket.arn,
          "${aws_s3_bucket.textbook_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_key_pair" "learnai_key" {
  key_name   = "learnai-key"
  public_key = file("${path.module}/learnai-key.pub")
}

# IAM Role for EC2 to access Bedrock
resource "aws_iam_role" "ec2_role" {
  name = "ec2-bedrock-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_bedrock_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
  role       = aws_iam_role.ec2_role.name
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-bedrock-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance for running the application
resource "aws_instance" "learnai_app" {
  ami                    = "ami-0ebfd941bbafe70c6" # Amazon Linux 2 AMI (adjust for your region)
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.learnai_key.key_name
  vpc_security_group_ids = [aws_security_group.learnai_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "LearnAI-App-Server"
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "Starting user data script"
              
              # Update and install dependencies
              yum update -y
              yum install -y python3 python3-pip git

              # Install Node.js v20 and npm
              curl -sL https://rpm.nodesource.com/setup_20.x | bash -
              yum install -y nodejs
              
              # Upgrade pip
              python3 -m pip install --upgrade pip
              
              # Clone the repository
              git clone https://github.com/manvirchakal/LearnAI /home/ec2-user/learnai
              
              # Create .env file with credentials
              cat <<EOT > /home/ec2-user/learnai/.env
              AWS_ACCESS_KEY_ID=${var.aws_access_key}
              AWS_SECRET_ACCESS_KEY=${var.aws_secret_key}
              AWS_DEFAULT_REGION=${var.aws_region}
              EOT
              
              # Set correct ownership
              sudo chown -R ec2-user:ec2-user /home/ec2-user/learnai

              # Install project dependencies
              cd /home/ec2-user/learnai/client
              sudo npm install --legacy-peer-deps

              #install python dependencies
              cd /home/ec2-user/learnai
              pip3 install -r requirements.txt

              echo "User data script complete"
              echo "Contents of .env file:"
              cat /home/ec2-user/learnai/.env
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
