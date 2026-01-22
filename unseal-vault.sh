#!/bin/bash
# Unseal Vault using saved keys
# This script unseals Vault using keys from ~/vault-init.json

set -euo pipefail

echo "============================================"
echo "  Vault Unseal"
echo "============================================"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform/control"
KEYS_FILE="$HOME/vault-init.json"

# Check if keys file exists
if [ ! -f "$KEYS_FILE" ]; then
  echo "❌ Vault keys file not found: $KEYS_FILE"
  echo ""
  echo "If Vault is not initialized yet, run:"
  echo "  ./setup-vault.sh"
  echo ""
  echo "If you have the keys elsewhere, you can manually unseal:"
  echo "  ssh to instance and run:"
  echo "    VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal <key1>"
  echo "    VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal <key2>"
  echo "    VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal <key3>"
  exit 1
fi

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

# Check Vault status
echo "Checking Vault status..."
VAULT_STATUS=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json" 2>/dev/null || echo '{}')

INITIALIZED=$(echo "$VAULT_STATUS" | jq -r '.initialized // false')
SEALED=$(echo "$VAULT_STATUS" | jq -r '.sealed // true')

if [ "$INITIALIZED" = "false" ]; then
  echo "❌ Vault is not initialized yet!"
  echo ""
  echo "Run ./setup-vault.sh to initialize Vault first."
  exit 1
fi

if [ "$SEALED" = "false" ]; then
  echo "✅ Vault is already unsealed!"
  exit 0
fi

echo "Vault is sealed. Unsealing..."
echo ""

# Load unseal keys
UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$KEYS_FILE")
UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$KEYS_FILE")

# Unseal Vault (requires 3 of 5 keys)
echo "Unsealing with key 1/3..."
UNSEAL_1=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal -format=json '$UNSEAL_KEY_1'")

PROGRESS=$(echo "$UNSEAL_1" | jq -r '.progress')
echo "  Progress: $PROGRESS/3"

echo "Unsealing with key 2/3..."
UNSEAL_2=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal -format=json '$UNSEAL_KEY_2'")

PROGRESS=$(echo "$UNSEAL_2" | jq -r '.progress')
echo "  Progress: $PROGRESS/3"

echo "Unsealing with key 3/3..."
UNSEAL_3=$(ssh -i "$SSH_KEY_PATH" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  ubuntu@"$INSTANCE_IP" \
  "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal -format=json '$UNSEAL_KEY_3'")

SEALED_FINAL=$(echo "$UNSEAL_3" | jq -r '.sealed')

if [ "$SEALED_FINAL" = "false" ]; then
  echo ""
  echo "✅ Vault unsealed successfully!"
  echo ""
  
  ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
  echo "Vault is now ready to use:"
  echo "  Vault UI: http://$INSTANCE_IP:8200"
  echo "  Root Token: $ROOT_TOKEN"
  echo ""
  echo "To log in via CLI:"
  echo "  export VAULT_ADDR=http://$INSTANCE_IP:8200"
  echo "  export VAULT_TOKEN=$ROOT_TOKEN"
  echo "  vault status"
else
  echo ""
  echo "❌ Failed to unseal Vault"
  exit 1
fi
echo ""
