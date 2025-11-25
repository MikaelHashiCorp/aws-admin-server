#!/bin/bash
set -euo pipefail

# User data script for AWS Admin Server
# Installs required packages for HashiStack management

exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting user-data script ==="
date

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

echo "=== User-data script completed ==="
date

# Signal completion
touch /var/lib/cloud/instance/user-data-finished
