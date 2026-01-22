#!/bin/bash
# Install Vault management scripts on the instance
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform/control"

# Get instance IP
cd "$TF_DIR"
INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
SSH_KEY=$(terraform output -raw ssh_key_name 2>/dev/null || echo "")
cd - > /dev/null

if [ -z "$INSTANCE_IP" ]; then
  echo "❌ Could not retrieve instance IP"
  exit 1
fi

SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY.pem"

echo "Installing Vault management scripts on instance: $INSTANCE_IP"
echo ""

# Create temporary directory with scripts
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Create vault-status.sh
cat > "$TEMP_DIR/vault-status.sh" <<'EOF'
#!/bin/bash
# Show Vault status with helpful info
export VAULT_ADDR=http://127.0.0.1:8200
echo "============================================"
echo "  Vault Status"
echo "============================================"
echo ""
vault status || true
echo ""
echo "Available commands:"
echo "  vault-status.sh  - Show this status"
echo "  vault-unseal.sh  - Unseal Vault"
echo "  vault-seal.sh    - Seal Vault"
echo ""
if [ -f "/home/ubuntu/vault-keys.json" ]; then
  echo "Keys file: /home/ubuntu/vault-keys.json"
elif [ -f "/root/vault-keys.json" ]; then
  echo "Keys file: /root/vault-keys.json"
else
  echo "ℹ️  No keys file found."
fi
echo ""
EOF

# Create vault-unseal.sh
cat > "$TEMP_DIR/vault-unseal.sh" <<'EOF'
#!/bin/bash
# Unseal Vault using saved keys
set -euo pipefail
export VAULT_ADDR=http://127.0.0.1:8200
echo "============================================"
echo "  Vault Unseal"
echo "============================================"
echo ""
KEYS_FILE=""
if [ -f "/home/ubuntu/vault-keys.json" ]; then
  KEYS_FILE="/home/ubuntu/vault-keys.json"
elif [ -f "/root/vault-keys.json" ]; then
  KEYS_FILE="/root/vault-keys.json"
else
  echo "❌ Keys file not found!"
  echo ""
  echo "Expected: /home/ubuntu/vault-keys.json or /root/vault-keys.json"
  echo ""
  echo "If not initialized, run: vault-init.sh"
  echo "Or manually: vault operator unseal <key>"
  exit 1
fi
VAULT_STATUS=$(vault status -format=json 2>/dev/null || echo '{}')
INITIALIZED=$(echo "$VAULT_STATUS" | jq -r '.initialized // false')
SEALED=$(echo "$VAULT_STATUS" | jq -r '.sealed // true')
if [ "$INITIALIZED" = "false" ]; then
  echo "❌ Vault not initialized. Run: vault-init.sh"
  exit 1
fi
if [ "$SEALED" = "false" ]; then
  echo "✅ Vault is already unsealed!"
  exit 0
fi
echo "Unsealing Vault..."
KEY1=$(jq -r '.unseal_keys_b64[0]' "$KEYS_FILE")
KEY2=$(jq -r '.unseal_keys_b64[1]' "$KEYS_FILE")
KEY3=$(jq -r '.unseal_keys_b64[2]' "$KEYS_FILE")
echo "  Progress: 1/3"
vault operator unseal "$KEY1" > /dev/null
echo "  Progress: 2/3"
vault operator unseal "$KEY2" > /dev/null
echo "  Progress: 3/3"
vault operator unseal "$KEY3" > /dev/null
echo ""
echo "✅ Vault unsealed successfully!"
echo ""
ROOT_TOKEN=$(jq -r '.root_token' "$KEYS_FILE")
echo "Root Token: $ROOT_TOKEN"
echo ""
echo "To use Vault:"
echo "  export VAULT_ADDR=http://127.0.0.1:8200"
echo "  export VAULT_TOKEN=$ROOT_TOKEN"
echo ""
EOF

# Create vault-seal.sh
cat > "$TEMP_DIR/vault-seal.sh" <<'EOF'
#!/bin/bash
# Seal Vault (lock it)
export VAULT_ADDR=http://127.0.0.1:8200
echo "============================================"
echo "  Vault Seal"
echo "============================================"
echo ""
TOKEN=""
if [ -f "/home/ubuntu/vault-keys.json" ]; then
  TOKEN=$(jq -r '.root_token' /home/ubuntu/vault-keys.json)
elif [ -f "/root/vault-keys.json" ]; then
  TOKEN=$(jq -r '.root_token' /root/vault-keys.json)
fi
if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
  export VAULT_TOKEN="$TOKEN"
fi
if ! vault status > /dev/null 2>&1; then
  echo "ℹ️  Vault is already sealed."
  exit 0
fi
echo "Sealing Vault..."
vault operator seal 2>&1 || true
echo ""
echo "✅ Vault sealed successfully!"
echo ""
echo "To unseal: vault-unseal.sh"
echo ""
EOF

# Copy keys file to instance
echo "1. Copying vault keys to instance..."
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
  "$HOME/vault-init.json" ubuntu@"$INSTANCE_IP":/home/ubuntu/vault-keys.json

echo "2. Copying management scripts..."
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
  "$TEMP_DIR/vault-status.sh" \
  "$TEMP_DIR/vault-unseal.sh" \
  "$TEMP_DIR/vault-seal.sh" \
  ubuntu@"$INSTANCE_IP":/tmp/

echo "3. Installing scripts..."
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$INSTANCE_IP" \
  "sudo mv /tmp/vault-*.sh /usr/local/bin/ && \
   sudo chmod +x /usr/local/bin/vault-*.sh && \
   chmod 600 /home/ubuntu/vault-keys.json"

echo ""
echo "✅ Installation complete!"
echo ""
echo "Scripts installed on instance:"
echo "  - vault-status.sh"
echo "  - vault-unseal.sh"
echo "  - vault-seal.sh"
echo ""
echo "To test, SSH to instance and run: vault-status.sh"
echo ""
