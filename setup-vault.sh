#!/bin/bash
# Setup and Initialize Vault
# This script initializes Vault, saves the unseal keys and root token securely

set -euo pipefail

echo "============================================"
echo "  Vault Initialization and Setup"
echo "============================================"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform/control"

# Check if Terraform outputs are available
if [ ! -f "$TF_DIR/terraform.tfstate" ]; then
  echo "❌ Terraform state file not found. Has the infrastructure been deployed?"
  exit 1
fi

# Extract instance information
cd "$TF_DIR"
INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
SSH_KEY=$(terraform output -raw ssh_key_name 2>/dev/null || echo "")
cd - > /dev/null

if [ -z "$INSTANCE_IP" ]; then
  echo "❌ Could not retrieve instance IP from Terraform outputs"
  exit 1
fi

SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY.pem"

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "❌ SSH key not found: $SSH_KEY_PATH"
  exit 1
fi

echo "Instance: $INSTANCE_IP"
echo ""

# Check if Vault is already initialized
echo "Checking Vault status..."
VAULT_STATUS=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json" 2>/dev/null || echo '{}')

INITIALIZED=$(echo "$VAULT_STATUS" | jq -r '.initialized // false')

if [ "$INITIALIZED" = "true" ]; then
  echo "✅ Vault is already initialized!"
  echo ""
  SEALED=$(echo "$VAULT_STATUS" | jq -r '.sealed // true')
  
  if [ "$SEALED" = "true" ]; then
    echo "⚠️  Vault is sealed. To unseal, run:"
    echo "   ./unseal-vault.sh"
    echo ""
    echo "Or manually unseal with keys from: ~/vault-init.json"
  else
    echo "✅ Vault is unsealed and ready to use!"
  fi
  exit 0
fi

echo "Initializing Vault..."
echo ""

# Initialize Vault with 5 key shares and threshold of 3
INIT_OUTPUT=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault operator init -key-shares=5 -key-threshold=3 -format=json")

echo "✅ Vault initialized successfully!"
echo ""

# Save initialization data locally
KEYS_FILE="$HOME/vault-init.json"
echo "$INIT_OUTPUT" > "$KEYS_FILE"
chmod 600 "$KEYS_FILE"

echo "🔐 Vault unseal keys and root token saved to: $KEYS_FILE"
echo ""

# Extract keys and token
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
UNSEAL_KEY_1=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[2]')

echo "============================================"
echo "  🔑 IMPORTANT - SAVE THESE CREDENTIALS 🔑"
echo "============================================"
echo ""
echo "Root Token:"
echo "  $ROOT_TOKEN"
echo ""
echo "Unseal Keys (need 3 of 5 to unseal):"
echo "  Key 1: $UNSEAL_KEY_1"
echo "  Key 2: $UNSEAL_KEY_2"
echo "  Key 3: $UNSEAL_KEY_3"
echo "  Key 4: $(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[3]')"
echo "  Key 5: $(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[4]')"
echo ""
echo "⚠️  CRITICAL: Store these credentials securely!"
echo "   - These keys cannot be recovered if lost"
echo "   - Never commit them to version control"
echo "   - Consider using a password manager or secret vault"
echo ""
echo "============================================"
echo ""

# Unseal Vault automatically
echo "Unsealing Vault with first 3 keys..."

ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '$UNSEAL_KEY_1'" > /dev/null

ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '$UNSEAL_KEY_2'" > /dev/null

ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '$UNSEAL_KEY_3'" > /dev/null

echo "✅ Vault unsealed successfully!"
echo ""
echo "Vault is now ready to use:"
echo "  Vault UI: http://$INSTANCE_IP:8200"
echo "  Root Token: $ROOT_TOKEN"
echo ""
echo "To log in via CLI:"
echo "  export VAULT_ADDR=http://$INSTANCE_IP:8200"
echo "  export VAULT_TOKEN=$ROOT_TOKEN"
echo "  vault status"
echo ""
