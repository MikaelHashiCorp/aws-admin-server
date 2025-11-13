#!/bin/bash
# Quick Start Guide for AWS Admin Server
# This script provides an interactive setup guide

set -euo pipefail

echo "=========================================="
echo "  AWS Admin Server - Quick Start Guide"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "pre-flight-check.sh" ]; then
  echo "❌ Error: Please run this script from the project root directory"
  exit 1
fi

echo "This guide will help you deploy the AWS Admin Server."
echo ""

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
echo ""

if ! command -v terraform &> /dev/null; then
  echo "❌ Terraform not found. Please install Terraform >= 1.5.0"
  exit 1
fi

if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI not found. Please install AWS CLI v2"
  exit 1
fi

echo "✅ Prerequisites installed"
echo ""

# Step 2: Check AWS authentication
echo "Step 2: Checking AWS authentication..."
echo ""

if ! aws sts get-caller-identity &> /dev/null; then
  echo "❌ AWS credentials not configured"
  echo ""
  echo "Please authenticate via Doormat:"
  echo "  doormat login -f"
  echo "  eval \$(doormat aws export --account <your_doormat_account>)"
  echo ""
  echo "Then run this script again."
  exit 1
fi

echo "✅ AWS credentials valid"
aws sts get-caller-identity --output table
echo ""

# Step 3: Check terraform.tfvars
echo "Step 3: Checking Terraform configuration..."
echo ""

if [ ! -f "terraform/control/terraform.tfvars" ]; then
  echo "⚠️  terraform.tfvars not found"
  echo ""
  echo "Would you like to create it from the example? (y/n)"
  read -r response
  
  if [[ "$response" =~ ^[Yy]$ ]]; then
    cp terraform/control/terraform.tfvars.example terraform/control/terraform.tfvars
    echo "✅ Created terraform/control/terraform.tfvars"
    echo ""
    echo "⚠️  IMPORTANT: Edit terraform/control/terraform.tfvars with your settings:"
    echo "   - region"
    echo "   - availability_zones"
    echo "   - key_name (your SSH key)"
    echo "   - owner_name"
    echo "   - owner_email"
    echo "   - instance_name"
    echo ""
    echo "Press Enter when you've finished editing..."
    read -r
  else
    echo "Please create terraform/control/terraform.tfvars manually and run this script again."
    exit 1
  fi
else
  echo "✅ terraform.tfvars exists"
fi

echo ""

# Step 4: Run pre-flight check
echo "Step 4: Running pre-flight checks..."
echo ""
./pre-flight-check.sh

echo ""

# Step 5: Deploy
echo "Step 5: Ready to deploy!"
echo ""
echo "Would you like to proceed with deployment? (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
  cd terraform/control
  
  echo ""
  echo "Enabling verbose logging..."
  export TF_LOG=DEBUG
  export TF_LOG_PATH=terraform-debug.log
  
  echo ""
  echo "Initializing Terraform..."
  terraform init
  
  echo ""
  echo "Planning deployment..."
  terraform plan -out=tfplan
  
  echo ""
  echo "Would you like to apply this plan? (y/n)"
  read -r apply_response
  
  if [[ "$apply_response" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Applying configuration..."
    terraform apply tfplan
    
    echo ""
    echo "=========================================="
    echo "  ✅ Deployment Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Run validation: cd ../.. && ./validate-instance.sh"
    echo "  2. Connect via SSH (see outputs above)"
    echo ""
  else
    echo "Deployment cancelled. You can apply manually with:"
    echo "  cd terraform/control && terraform apply tfplan"
  fi
  
  cd ../..
else
  echo ""
  echo "Deployment skipped. To deploy manually:"
  echo "  cd terraform/control"
  echo "  export TF_LOG=DEBUG"
  echo "  export TF_LOG_PATH=terraform-debug.log"
  echo "  terraform init"
  echo "  terraform plan -out=tfplan"
  echo "  terraform apply tfplan"
fi

echo ""
