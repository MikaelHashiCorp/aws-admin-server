#!/bin/bash
set -euo pipefail

# User data script for AWS Admin Server
# Installs required packages for HashiStack management

exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting user-data script ==="
date

# Function to wait for dpkg locks to be released
wait_for_dpkg() {
  echo "Waiting for dpkg locks to be released..."
  local max_attempts=60
  local attempt=0
  
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
        fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
        fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if [ $attempt -ge $max_attempts ]; then
      echo "ERROR: Timeout waiting for dpkg locks after $max_attempts attempts"
      return 1
    fi
    echo "dpkg is locked, waiting... (attempt $((attempt+1))/$max_attempts)"
    sleep 10
    attempt=$((attempt+1))
  done
  
  echo "dpkg locks released, proceeding..."
  return 0
}

# Wait for any existing package operations to complete
wait_for_dpkg

# Update system packages
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install basic utilities
echo "Installing basic utilities..."
apt-get install -y \
  curl \
  wget \
  unzip \
  jq \
  net-tools \
  software-properties-common \
  gnupg

# Add HashiCorp GPG key and repository
echo "Adding HashiCorp repository..."
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  tee /etc/apt/sources.list.d/hashicorp.list

apt-get update

# Install HashiCorp tools
echo "Installing HashiCorp tools..."
apt-get install -y \
  consul \
  nomad \
  vault \
  terraform \
  packer

# Install AWS CLI v2
echo "Installing AWS CLI..."
if ! command -v aws &> /dev/null; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  rm -rf aws awscliv2.zip
fi

# Configure timezone
echo "Configuring timezone..."
timedatectl set-timezone UTC

# Create workspace directories
echo "Creating workspace directories..."
mkdir -p /opt/hashicorp/{consul,nomad,vault,packer,terraform}
mkdir -p /opt/consul/data
mkdir -p /opt/nomad/data
mkdir -p /opt/vault/data
chown -R ubuntu:ubuntu /opt/hashicorp
chown -R consul:consul /opt/consul
chown -R nomad:nomad /opt/nomad
chown -R vault:vault /opt/vault

# Configure Consul
echo "Configuring Consul..."
cat > /etc/consul.d/consul.hcl <<'EOF'
datacenter = "dc1"
data_dir = "/opt/consul/data"
client_addr = "0.0.0.0"
bind_addr = "{{ GetPrivateInterfaces | attr \"address\" }}"
advertise_addr = "{{ GetPrivateInterfaces | attr \"address\" }}"
server = true
bootstrap_expect = 1
ui_config {
  enabled = true
}
log_level = "INFO"
EOF

chown consul:consul /etc/consul.d/consul.hcl
chmod 640 /etc/consul.d/consul.hcl

# Fix Consul systemd service type (Type=notify causes it to stay in activating state)
echo "Fixing Consul systemd service configuration..."
mkdir -p /etc/systemd/system/consul.service.d
cat > /etc/systemd/system/consul.service.d/override.conf <<'EOF'
[Service]
Type=exec
EOF

# Configure Nomad - Use existing config which is properly setup
echo "Using default Nomad configuration..."

# Configure Vault
echo "Configuring Vault..."
cat > /etc/vault.d/vault.hcl <<'EOF'
ui = true
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

log_level = "INFO"
EOF

chown vault:vault /etc/vault.d/vault.hcl
chmod 640 /etc/vault.d/vault.hcl

# Set Vault environment variable system-wide
echo "export VAULT_ADDR=http://127.0.0.1:8200" >> /etc/environment
echo "export VAULT_ADDR=http://127.0.0.1:8200" >> /etc/profile.d/vault.sh
chmod +x /etc/profile.d/vault.sh

# Enable and start services
echo "Starting services..."
systemctl enable consul
systemctl enable nomad
systemctl enable vault

echo "Starting Consul (may take up to 2 minutes)..."
systemctl start consul || echo "Consul start reported error but service may still be running"
sleep 5

echo "Starting Nomad..."
systemctl start nomad || echo "Nomad start reported error but service may still be running"
sleep 3

echo "Starting Vault..."
systemctl start vault || echo "Vault start reported error but service may still be running"
sleep 5

# Check service status
echo "Checking service status..."
systemctl status consul --no-pager || true
systemctl status nomad --no-pager || true
systemctl status vault --no-pager || true

# Verify HashiStack services
echo "Verifying HashiStack services..."
export VAULT_ADDR=http://127.0.0.1:8200
consul members || echo "Consul not ready yet"
nomad server members || echo "Nomad not ready yet"
VAULT_ADDR=http://127.0.0.1:8200 vault status || echo "Vault not ready yet"

# Create Vault management scripts for local use
echo "Creating Vault management scripts..."
cat > /usr/local/bin/vault-init.sh <<'VAULT_INIT_EOF'
#!/bin/bash
# Initialize Vault (run once)
set -euo pipefail

export VAULT_ADDR=http://127.0.0.1:8200

echo "============================================"
echo "  Vault Initialization"
echo "============================================"
echo ""

# Check if already initialized
VAULT_STATUS=$(vault status -format=json 2>/dev/null || echo '{}')
INITIALIZED=$(echo "$VAULT_STATUS" | jq -r '.initialized // false')

if [ "$INITIALIZED" = "true" ]; then
  echo "✅ Vault is already initialized!"
  echo ""
  SEALED=$(echo "$VAULT_STATUS" | jq -r '.sealed // true')
  if [ "$SEALED" = "true" ]; then
    echo "⚠️  Vault is sealed. To unseal, run: vault-unseal.sh"
  else
    echo "✅ Vault is unsealed and ready!"
  fi
  exit 0
fi

echo "Initializing Vault with 5 keys (threshold: 3)..."
INIT_OUTPUT=$(vault operator init -key-shares=5 -key-threshold=3 -format=json)

# Save to ubuntu user's home and /root
KEYS_FILE="/home/ubuntu/vault-keys.json"
echo "$INIT_OUTPUT" > "$KEYS_FILE"
chmod 600 "$KEYS_FILE"
chown ubuntu:ubuntu "$KEYS_FILE"

cp "$KEYS_FILE" /root/vault-keys.json
chmod 600 /root/vault-keys.json

echo "✅ Vault initialized successfully!"
echo ""
echo "🔐 Keys saved to: $KEYS_FILE and /root/vault-keys.json"
echo ""

# Display credentials
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
echo "============================================"
echo "  🔑 SAVE THESE CREDENTIALS SECURELY 🔑"
echo "============================================"
echo ""
echo "Root Token:"
echo "  $ROOT_TOKEN"
echo ""
echo "Unseal Keys (need 3 of 5):"
for i in {0..4}; do
  KEY=$(echo "$INIT_OUTPUT" | jq -r ".unseal_keys_b64[$i]")
  echo "  Key $((i+1)): $KEY"
done
echo ""
echo "⚠️  Store these securely - they cannot be recovered!"
echo ""

# Auto-unseal
echo "Unsealing Vault automatically..."
KEY1=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[0]')
KEY2=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[1]')
KEY3=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[2]')

vault operator unseal "$KEY1" > /dev/null
vault operator unseal "$KEY2" > /dev/null
vault operator unseal "$KEY3" > /dev/null

echo "✅ Vault unsealed and ready to use!"
echo ""
echo "To use Vault:"
echo "  export VAULT_ADDR=http://127.0.0.1:8200"
echo "  export VAULT_TOKEN=$ROOT_TOKEN"
echo "  vault status"
echo ""
VAULT_INIT_EOF

cat > /usr/local/bin/vault-unseal.sh <<'VAULT_UNSEAL_EOF'
#!/bin/bash
# Unseal Vault using saved keys
set -euo pipefail

export VAULT_ADDR=http://127.0.0.1:8200

echo "============================================"
echo "  Vault Unseal"
echo "============================================"
echo ""

# Find keys file
KEYS_FILE=""
if [ -f "/home/ubuntu/vault-keys.json" ]; then
  KEYS_FILE="/home/ubuntu/vault-keys.json"
elif [ -f "/root/vault-keys.json" ]; then
  KEYS_FILE="/root/vault-keys.json"
else
  echo "❌ Keys file not found!"
  echo ""
  echo "Expected locations:"
  echo "  /home/ubuntu/vault-keys.json"
  echo "  /root/vault-keys.json"
  echo ""
  echo "If not initialized, run: vault-init.sh"
  echo ""
  echo "Manual unseal:"
  echo "  vault operator unseal <key1>"
  echo "  vault operator unseal <key2>"
  echo "  vault operator unseal <key3>"
  exit 1
fi

# Check status
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

echo "  Unseal progress: 1/3"
vault operator unseal "$KEY1" > /dev/null

echo "  Unseal progress: 2/3"
vault operator unseal "$KEY2" > /dev/null

echo "  Unseal progress: 3/3"
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
VAULT_UNSEAL_EOF

cat > /usr/local/bin/vault-seal.sh <<'VAULT_SEAL_EOF'
#!/bin/bash
# Seal Vault (lock it)
set -euo pipefail

export VAULT_ADDR=http://127.0.0.1:8200

echo "============================================"
echo "  Vault Seal"
echo "============================================"
echo ""

# Check status (allow command to fail gracefully)
# Note: exit code 2 means sealed, exit code 1 means error, exit code 0 means unsealed
set +e
VAULT_STATUS=$(vault status -format=json 2>&1)
VAULT_EXIT_CODE=$?
set -e

# Check if we got valid JSON
if ! echo "$VAULT_STATUS" | jq -e . >/dev/null 2>&1; then
  echo "❌ Unable to get Vault status."
  exit 1
fi

# Parse status (don't use // operator as it triggers on false booleans)
INITIALIZED=$(echo "$VAULT_STATUS" | jq -r '.initialized')
SEALED=$(echo "$VAULT_STATUS" | jq -r '.sealed')

if [ "$INITIALIZED" = "false" ]; then
  echo "❌ Vault not initialized."
  exit 1
fi

if [ "$SEALED" = "true" ]; then
  echo "ℹ️  Vault is already sealed."
  exit 0
fi

# Find root token
TOKEN=""
if [ -f "/home/ubuntu/vault-keys.json" ]; then
  TOKEN=$(jq -r '.root_token' /home/ubuntu/vault-keys.json)
elif [ -f "/root/vault-keys.json" ]; then
  TOKEN=$(jq -r '.root_token' /root/vault-keys.json)
fi

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
  export VAULT_TOKEN="$TOKEN"
fi

echo "Sealing Vault..."
vault operator seal

echo ""
echo "✅ Vault sealed successfully!"
echo ""
echo "To unseal Vault, run: vault-unseal.sh"
echo ""
VAULT_SEAL_EOF

cat > /usr/local/bin/vault-status.sh <<'VAULT_STATUS_EOF'
#!/bin/bash
# Show Vault status with helpful info
set -euo pipefail

export VAULT_ADDR=http://127.0.0.1:8200

echo "============================================"
echo "  Vault Status"
echo "============================================"
echo ""

vault status

echo ""
echo "Available commands:"
echo "  vault-init.sh    - Initialize Vault (first time only)"
echo "  vault-unseal.sh  - Unseal Vault"
echo "  vault-seal.sh    - Seal Vault"
echo "  vault-status.sh  - Show this status"
echo ""

# Show keys location if they exist
if [ -f "/home/ubuntu/vault-keys.json" ]; then
  echo "Keys file: /home/ubuntu/vault-keys.json"
elif [ -f "/root/vault-keys.json" ]; then
  echo "Keys file: /root/vault-keys.json"
else
  echo "ℹ️  No keys file found. Run vault-init.sh to initialize."
fi
echo ""
VAULT_STATUS_EOF

# Make scripts executable
chmod +x /usr/local/bin/vault-init.sh
chmod +x /usr/local/bin/vault-unseal.sh
chmod +x /usr/local/bin/vault-seal.sh
chmod +x /usr/local/bin/vault-status.sh

echo "✅ Vault management scripts installed:"
echo "   - vault-init.sh"
echo "   - vault-unseal.sh"
echo "   - vault-seal.sh"
echo "   - vault-status.sh"

echo "=== User-data script completed ==="
date

# Signal completion
touch /var/lib/cloud/instance/user-data-finished
