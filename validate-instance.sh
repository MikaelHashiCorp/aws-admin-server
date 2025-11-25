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

# Check HashiStack service status
echo ""
echo "7. Checking HashiStack service status..."

CONSUL_STATUS=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" "systemctl is-active consul" 2>/dev/null || echo "inactive")

NOMAD_STATUS=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" "systemctl is-active nomad" 2>/dev/null || echo "inactive")

VAULT_STATUS=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" "systemctl is-active vault" 2>/dev/null || echo "inactive")

echo "   Consul: $CONSUL_STATUS"
echo "   Nomad: $NOMAD_STATUS"
echo "   Vault: $VAULT_STATUS"

# Verify HashiStack services are functional
echo ""
echo "8. Verifying HashiStack service functionality..."

CONSUL_MEMBERS=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" "consul members 2>&1" || echo "error")

if echo "$CONSUL_MEMBERS" | grep -q "alive"; then
  echo "   ✅ Consul is functional (members visible)"
else
  echo "   ❌ Consul is not functional: $CONSUL_MEMBERS"
fi

NOMAD_SERVERS=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" "nomad server members 2>&1" || echo "error")

if echo "$NOMAD_SERVERS" | grep -q "alive"; then
  echo "   ✅ Nomad is functional (server members visible)"
else
  echo "   ❌ Nomad is not functional: $NOMAD_SERVERS"
fi

VAULT_STATUS_CHECK=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" "VAULT_ADDR=http://127.0.0.1:8200 vault status 2>&1" || echo "error")

if echo "$VAULT_STATUS_CHECK" | grep -q "Initialized"; then
  echo "   ✅ Vault is functional (responding to queries)"
else
  echo "   ❌ Vault is not functional: $VAULT_STATUS_CHECK"
fi

# Summary
echo ""
echo "============================================"
if [ ${#MISSING_PACKAGES[@]} -eq 0 ] && \
   [ "$CONSUL_STATUS" = "active" ] && \
   [ "$NOMAD_STATUS" = "active" ] && \
   [ "$VAULT_STATUS" = "active" ] && \
   echo "$CONSUL_MEMBERS" | grep -q "alive" && \
   echo "$NOMAD_SERVERS" | grep -q "alive" && \
   echo "$VAULT_STATUS_CHECK" | grep -q "Initialized"; then
  echo "  ✅ All validation checks passed!"
  echo "============================================"
  echo ""
  echo "Instance is ready for use:"
  echo "  ssh -i $SSH_KEY_PATH ubuntu@$INSTANCE_IP"
  echo ""
  echo "HashiStack Services:"
  echo "  Consul UI: http://$INSTANCE_IP:8500"
  echo "  Nomad UI:  http://$INSTANCE_IP:4646"
  echo "  Vault API: http://$INSTANCE_IP:8200"
else
  echo "  ⚠️  Validation completed with warnings"
  echo "============================================"
  echo ""
  if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "Missing packages: ${MISSING_PACKAGES[*]}"
  fi
  echo "Service status:"
  echo "  Consul: $CONSUL_STATUS"
  echo "  Nomad:  $NOMAD_STATUS"
  echo "  Vault:  $VAULT_STATUS"
fi
echo ""

cd - > /dev/null
