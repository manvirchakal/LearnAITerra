# LearnAI Infrastructure Setup

This repository contains Terraform scripts to set up the infrastructure for the LearnAI project on AWS.

## Prerequisites

- Terraform installed on your machine
- AWS CLI installed and configured
- Git installed

## Setup
1. Create a terraform.tfvars file in the root directory with your AWS credentials:

   - aws_region     = "{your region}"
   - aws_access_key = "{your access key}"
   - aws_secret_key = "{your secret key}"

   Replace your_access_key, your_secret_key, and your_preferred_region with your actual AWS credentials and preferred region.

2. The repository includes two scripts for running Terraform commands:

   - For Windows (PowerShell): '.\Run-Terraform.ps1'
   - For Linux/macOS: '.\run-terraform.sh'

   Make the bash script executable (Linux/macOS only): 'chmod +x run-terraform.sh'

3. Create a new key pair in AWS for the EC2 instance and name it learnai-key:
   
   - Run the following command to create a new key pair: 'ssh-keygen -t rsa -b 2048 -f learnai-key'
   - This will generate learnai-key and learnai-key.pub files in the current directory.
   - Keep the private key (learnai-key) in a secure location. The public key (learnai-key.pub) will be used in the Terraform configuration.

## Usage

To run Terraform commands, use the appropriate script for your operating system:

On Windows (PowerShell):
.\Run-Terraform.ps1 init
.\Run-Terraform.ps1 plan
.\Run-Terraform.ps1 apply

On Linux/macOS:
./run-terraform.sh init
./run-terraform.sh plan
./run-terraform.sh apply

These commands will:
1. Initialize Terraform
2. Show you the planned changes
3. Apply the changes to create the infrastructure

## Infrastructure Components

This Terraform configuration will create:
- An AWS Cognito User Pool
- An S3 bucket for storing textbooks
- An EC2 instance for running the application
- A security group for the EC2 instance
- An IAM role for the EC2 instance to access S3
- An IAM role for the EC2 instance to access AWS Bedrock
- A Knowledge Base in AWS Bedrock

## Customization

You can customize the infrastructure by modifying the variables in the variables.tf file.

## Outputs

After applying the Terraform configuration, you'll receive the following outputs:
- Cognito User Pool ID
- Cognito Client ID
- S3 Bucket Name
- EC2 Instance Public IP
- Knowledge Base ID

You can view these outputs by running:

On Windows:
.\Run-Terraform.ps1 output

On Linux/macOS:
./run-terraform.sh output

## Cleanup

To destroy the created infrastructure, run:

On Windows:
.\Run-Terraform.ps1 destroy

On Linux/macOS:
./run-terraform.sh destroy

Note: Be cautious when using the destroy command as it will remove all created resources.

## Setting up the Virtual Environment and Client-Side

After setting up the infrastructure, please refer to the README.md file in the cloned LearnAI repository for instructions on:

1. Setting up the Python virtual environment
2. Installing required dependencies
3. Configuring and running the client-side application

You can find this README by navigating to the `/home/ec2-user/learnai` directory on your EC2 instance after the Terraform apply is complete.