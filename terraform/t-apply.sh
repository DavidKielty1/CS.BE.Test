#!/bin/bash

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install it first."
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "terraform.tfvars file not found!"
    exit 1
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Apply the configuration
echo "Applying Terraform configuration..."
terraform apply -auto-approve \
  -var-file="terraform.tfvars"

# Check if apply was successful
if [ $? -eq 0 ]; then
    echo "✅ Terraform apply completed successfully!"
else
    echo "❌ Terraform apply failed!"
    exit 1
fi 