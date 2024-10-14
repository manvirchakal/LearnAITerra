terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.69.0"  # Use the latest version that supports Bedrock
    }
  }
}

provider "aws" {
  region = var.aws_region
}