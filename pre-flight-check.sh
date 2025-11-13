#!/bin/bash
# Pre-flight Check for AWS Admin Server
# Run this before executing Terraform or Packer commands

set -euo pipefail

echo "=== Pre-flight Checks for AWS Admin Server ==="
echo ""

# Check 1: AWS Credentials
echo "1. Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
  echo "   ✅ AWS credentials are valid"
  aws sts get-caller-identity --output table
else
  echo "   ❌ AWS credentials are NOT configured or expired"
  echo ""
  echo "   To configure AWS credentials, run:"
  echo "   doormat login -f"
  echo "   eval \$(doormat aws export --account <your_doormat_account>)"
  echo ""
  exit 1
fi

# Check 2: Required tools
echo ""
echo "2. Checking required tools..."

MISSING_TOOLS=()

if ! command -v packer &> /dev/null; then
  MISSING_TOOLS+=("packer")
  echo "   ❌ packer not found"
else
  echo "   ✅ packer installed: $(packer version)"
fi

if ! command -v terraform &> /dev/null; then
  MISSING_TOOLS+=("terraform")
  echo "   ❌ terraform not found"
else
  echo "   ✅ terraform installed: $(terraform version | head -1)"
fi

if ! command -v jq &> /dev/null; then
  MISSING_TOOLS+=("jq")
  echo "   ❌ jq not found"
else
  echo "   ✅ jq installed"
fi

if ! command -v curl &> /dev/null; then
  MISSING_TOOLS+=("curl")
  echo "   ❌ curl not found"
else
  echo "   ✅ curl installed"
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
  echo ""
  echo "   Missing tools: ${MISSING_TOOLS[*]}"
  exit 1
fi

# Check 3: Terraform configuration
echo ""
echo "3. Checking Terraform configuration..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform/control"

if [ ! -d "$TF_DIR" ]; then
  echo "   ⚠️  Terraform control directory not found: $TF_DIR"
  echo "      This is expected for initial setup."
else
  echo "   ✅ Terraform directory exists"
  
  if [ -f "$TF_DIR/terraform.tfvars" ]; then
    echo "   ✅ terraform.tfvars exists"
    
    # Check key_name
    if grep -q "^key_name" "$TF_DIR/terraform.tfvars"; then
      KEY_NAME=$(grep "^key_name" "$TF_DIR/terraform.tfvars" | cut -d'"' -f2)
      echo "   ✅ SSH key configured: $KEY_NAME"
    else
      echo "   ⚠️  key_name not set in terraform.tfvars"
    fi
    
    # Validate Terraform configuration
    if command -v terraform &> /dev/null; then
      echo ""
      echo "   Validating Terraform configuration..."
      cd "$TF_DIR"
      if terraform validate &> /dev/null; then
        echo "   ✅ Terraform configuration is valid"
      else
        echo "   ⚠️  Terraform validation failed (run 'terraform validate' for details)"
      fi
      cd - > /dev/null
    fi
  else
    echo "   ⚠️  terraform.tfvars not found (expected for initial setup)"
  fi
fi

# Check 4: AWS Region access
echo ""
echo "4. Checking AWS region access..."

if [ -f "$TF_DIR/terraform.tfvars" ]; then
  REGION=$(grep '^region' "$TF_DIR/terraform.tfvars" | sed 's/region[[:space:]]*=[[:space:]]*"\(.*\)"/\1/' | tr -d ' ')
  if [ -z "$REGION" ]; then
    echo "   ⚠️  Could not read region from terraform.tfvars"
    REGION="us-east-1"  # Default fallback
  fi
else
  REGION="us-east-1"  # Default fallback
  echo "   Using default region: $REGION"
fi

if aws ec2 describe-regions --region $REGION --region-names $REGION &> /dev/null; then
  echo "   ✅ Can access region: $REGION"
else
  echo "   ⚠️  Cannot access region: $REGION (check credentials)"
fi

# Check 5: Disk space
echo ""
echo "5. Checking available disk space..."
AVAILABLE_GB=$(df -h . | awk 'NR==2 {print $4}' | sed 's/Gi//')
if [ "${AVAILABLE_GB%%.*}" -gt 10 ] 2>/dev/null; then
  echo "   ✅ Sufficient disk space available: ${AVAILABLE_GB}GB"
else
  echo "   ⚠️  Low disk space: ${AVAILABLE_GB}GB"
fi

# All checks passed
echo ""
echo "============================================"
echo "  ✅ Pre-flight checks complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Set up Terraform: cd terraform/control && terraform init"
echo "  2. Configure terraform.tfvars with your settings"
echo "  3. Plan deployment: terraform plan -out=tfplan"
echo "  4. Apply: terraform apply tfplan"
echo ""
