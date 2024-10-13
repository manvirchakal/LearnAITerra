#!/bin/bash

# Load environment variables from .env file
while IFS='=' read -r name value
do
    if [[ ! -z "$name" && ! "$name" =~ ^# ]]; then
        export "$name=$value"
        echo "Set $name to $value"  # Add this line for debugging
    fi
done < .env

# Print all AWS-related environment variables
env | grep AWS

# Run Terraform with all arguments passed to this script
terraform "$@"