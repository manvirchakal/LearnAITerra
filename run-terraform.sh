#!/bin/bash

# Load environment variables from .env file
while IFS='=' read -r name value
do
    if [[ ! -z "$name" && ! "$name" =~ ^# ]]; then
        export "$name=$value"
    fi
done < .env

# Run Terraform with all arguments passed to this script
terraform "$@"