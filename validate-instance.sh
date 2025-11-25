#!/bin/bash
# Validation Script for AWS Admin Server Instance
# Verifies instance is correctly configured and accessible

set -euo pipefail

echo "=== AWS Admin Server Instance Validation ==="
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform/control"

# Check if Terraform outputs are available
if [ ! -f "$TF_DIR/terraform.tfstate" ]; then
  echo "❌ Terraform state file not found. Has the infrastructure been deployed?"
  echo "   Expected: $TF_DIR/terraform.tfstate"
  exit 1
fi

# Extract instance information from Terraform
echo "1. Retrieving instance information from Terraform..."
cd "$TF_DIR"

INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
SSH_KEY=$(terraform output -raw ssh_key_name 2>/dev/null || echo "")

# Get region from terraform.tfvars
REGION=$(grep '^region' terraform.tfvars | sed 's/region[[:space:]]*=[[:space:]]*"\(.*\)"/\1/' | tr -d ' ')

if [ -z "$INSTANCE_IP" ]; then
  echo "   ❌ Could not retrieve instance IP from Terraform outputs"
  exit 1
fi

echo "   ✅ Instance IP: $INSTANCE_IP"
echo "   ✅ Instance ID: $INSTANCE_ID"
echo "   ✅ SSH Key: $SSH_KEY"
echo "   ✅ Region: $REGION"

# Check instance state in AWS
echo ""
echo "2. Checking instance state in AWS..."
INSTANCE_STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "unknown")

if [ "$INSTANCE_STATE" = "running" ]; then
  echo "   ✅ Instance is running"
else
  echo "   ❌ Instance state: $INSTANCE_STATE (expected: running)"
  exit 1
fi

# Test network connectivity
echo ""
echo "3. Testing network connectivity..."
if ping -c 3 -W 2 "$INSTANCE_IP" &> /dev/null; then
  echo "   ✅ Instance is reachable via ping"
else
  echo "   ⚠️  Instance not responding to ping (this may be expected if ICMP is disabled)"
fi

# Test SSH connectivity
echo ""
echo "4. Testing SSH connectivity..."
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY.pem"

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "   ❌ SSH key not found: $SSH_KEY_PATH"
  exit 1
fi

# Test SSH with timeout
if timeout 10 ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  -o BatchMode=yes \
  ubuntu@"$INSTANCE_IP" "echo 'SSH connection successful'" &> /dev/null; then
  echo "   ✅ SSH connection successful"
else
  echo "   ❌ SSH connection failed"
  echo "      Try manually: ssh -i $SSH_KEY_PATH ubuntu@$INSTANCE_IP"
  exit 1
fi

# Verify required packages are installed
echo ""
echo "5. Verifying required packages are installed..."

REQUIRED_PACKAGES=("jq" "nomad" "consul" "vault" "netstat")
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
  if ssh -i "$SSH_KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=5 \
    ubuntu@"$INSTANCE_IP" "command -v $package" &> /dev/null; then
    echo "   ✅ $package is installed"
  else
    echo "   ❌ $package is NOT installed"
    MISSING_PACKAGES+=("$package")
  fi
done

# Check OS version
echo ""
echo "6. Verifying OS version..."
OS_VERSION=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" "lsb_release -d" 2>/dev/null | cut -f2 || echo "unknown")

echo "   OS: $OS_VERSION"
if echo "$OS_VERSION" | grep -q "Ubuntu 24.04"; then
  echo "   ✅ Ubuntu 24.04 detected"
else
  echo "   ⚠️  Expected Ubuntu 24.04"
fi

# Summary
echo ""
echo "============================================"
if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
  echo "  ✅ All validation checks passed!"
  echo "============================================"
  echo ""
  echo "Instance is ready for use:"
  echo "  ssh -i $SSH_KEY_PATH ubuntu@$INSTANCE_IP"
else
  echo "  ⚠️  Validation completed with warnings"
  echo "============================================"
  echo ""
  echo "Missing packages: ${MISSING_PACKAGES[*]}"
  echo "You may need to install them manually or update the user-data script"
fi
echo ""

cd - > /dev/null
