variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "cognito_user_pool_name" {
  description = "Cognito User Pool name"
  default     = "learnai-user-pool"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storing textbooks"
  default     = "learnai-textbooks"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  default     = "t2.large"
}

variable "ec2_key_name" {
  description = "EC2 key pair name"
  default     = "learnai-key"
}
