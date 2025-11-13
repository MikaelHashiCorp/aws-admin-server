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
chown -R ubuntu:ubuntu /opt/hashicorp

# Enable and start services (but don't run them by default)
echo "Configuring services..."
systemctl enable consul
systemctl enable nomad
systemctl enable vault

echo "=== User-data script completed ==="
date

# Signal completion
touch /var/lib/cloud/instance/user-data-finished
