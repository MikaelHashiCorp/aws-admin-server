# Vault Quick Reference

## Scripts Overview

### Local Machine Scripts (run from your workstation)

| Script | Purpose |
|--------|---------|
| `./setup-vault.sh` | Initialize Vault for the first time (creates 5 keys, saves to `~/vault-init.json`) |
| `./unseal-vault.sh` | Unseal Vault remotely via SSH |
| `./install-vault-scripts.sh` | Install helper scripts on the instance |

### Instance Scripts (run on the AWS instance)

| Script | Purpose |
|--------|---------|
| `vault-status.sh` | Show Vault status and available commands |
| `vault-unseal.sh` | Unseal Vault using keys from `/home/ubuntu/vault-keys.json` |
| `vault-seal.sh` | Seal (lock) Vault immediately |

## Common Workflows

### First-Time Setup

```bash
# 1. Deploy infrastructure
./quick-start.sh

# 2. Initialize Vault (creates keys)
./setup-vault.sh

# 3. (Optional) Install instance scripts
./install-vault-scripts.sh
```

### Daily Operations - From Instance

```bash
# SSH to instance
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem ubuntu@<instance-ip>

# Check status
vault-status.sh

# Unseal if needed
vault-unseal.sh

# Work with Vault...
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<your-root-token>
vault kv put secret/myapp password=secret123

# Seal when done (optional)
vault-seal.sh
```

### Daily Operations - From Local Machine

```bash
# Check status
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem ubuntu@<instance-ip> "vault-status.sh"

# Unseal remotely
./unseal-vault.sh

# Access Vault UI
open http://<instance-ip>:8200
```

### After Instance Restart

Vault always starts sealed after a restart. You must unseal it:

**Method 1: From instance**
```bash
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem ubuntu@<instance-ip>
vault-unseal.sh
```

**Method 2: From local machine**
```bash
./unseal-vault.sh
```

## Key Management

### Unseal Keys Storage

- **Local machine**: `~/vault-init.json` (created by `setup-vault.sh`)
- **Instance**: `/home/ubuntu/vault-keys.json` (created by `install-vault-scripts.sh`)

### Key Information

- **Total keys**: 5
- **Threshold**: 3 (need 3 of 5 keys to unseal)
- **Root token**: Also stored in the same JSON files

### Security Notes

⚠️ **CRITICAL**: 
- Never commit these files to version control
- Store backups in secure locations (password manager, secure vault)
- Keys cannot be recovered if lost
- Consider HashiCorp Vault Enterprise for advanced key management

## Troubleshooting

### Vault won't unseal

```bash
# Check if keys file exists on instance
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem ubuntu@<instance-ip> "ls -la ~/vault-keys.json"

# If missing, copy from local machine
scp -i ~/.ssh/mhc-aws-mws-west-2.pem ~/vault-init.json ubuntu@<instance-ip>:/home/ubuntu/vault-keys.json
```

### Scripts not found on instance

```bash
# Install/reinstall scripts
./install-vault-scripts.sh

# Or manually install from user-data on new deployments
# (scripts are automatically created via user-data)
```

### Check Vault logs

```bash
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem ubuntu@<instance-ip>
sudo journalctl -u vault -n 50 --no-pager
```

## Advanced Usage

### Manual Operations

If you prefer not to use scripts:

```bash
# Unseal manually
export VAULT_ADDR=http://127.0.0.1:8200
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>

# Check status
vault status

# Seal manually
vault operator seal
```

### Auto-Unseal (Production)

For production environments, consider AWS KMS auto-unseal:

```hcl
# vault.hcl
seal "awskms" {
  region     = "us-west-2"
  kms_key_id = "your-kms-key-id"
}
```

This eliminates the need for manual unsealing after restarts.

## Resources

- [Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Seal/Unseal Concepts](https://developer.hashicorp.com/vault/docs/concepts/seal)
- [Auto-Unseal with AWS KMS](https://developer.hashicorp.com/vault/docs/configuration/seal/awskms)
