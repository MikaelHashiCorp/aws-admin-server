# Vault Management

This document provides instructions for initializing, unsealing, and managing Vault.

## Initial Setup

### Installing Instance Scripts (Optional)

For easier Vault management directly on the instance, install helper scripts:

```bash
./install-vault-scripts.sh
```

This installs the following commands on the instance:
- `vault-status.sh` - Show Vault status
- `vault-unseal.sh` - Unseal Vault using saved keys
- `vault-seal.sh` - Seal (lock) Vault

These scripts are automatically installed on new instances via user-data. This manual installation is only needed if you want to add them to an existing instance.

### Initialize Vault (First Time Only)

Run the initialization script to set up Vault with 5 unseal keys (threshold of 3):

```bash
./setup-vault.sh
```

This script will:
1. Initialize Vault with 5 unseal keys and a threshold of 3
2. Display all 5 unseal keys and the root token
3. Save credentials to `~/vault-init.json` (permissions: 600)
4. Automatically unseal Vault with the first 3 keys

**⚠️ CRITICAL: Save the unseal keys and root token securely!**
- These keys cannot be recovered if lost
- Never commit them to version control
- Store in a password manager or secure vault
- You need 3 of 5 keys to unseal Vault

### Sample Output

```
Root Token:
  hvs.B1UbCQUmfu0gEmkuKZ6RIhEl

Unseal Keys (need 3 of 5 to unseal):
  Key 1: iCdE7vHJe4Rv5V1txT/gUskxYSUTJYDoV3zCzWNKy/C6
  Key 2: cFQBilAw8k6qT7X1JmMpTm33Tzpx07yNIxovW8ElTRlW
  Key 3: 8RAYBWrNbVAtr18YfnE88JwBboaCfOw+gxj0SfwlGYvW
  Key 4: bPk0KKgIYc9BP1UyJ5LCRvEn2kSfd/4CjbXoA0PDhSTB
  Key 5: xrlC4mI50eM3j3aibbqQ4G3U+ugdpip0vC8oEAiQoMko
```

## Unsealing Vault

Vault starts in a sealed state after every restart or if explicitly sealed. You must unseal it before use.

### From Your Local Machine

Use the unseal script (requires `~/vault-init.json`):

```bash
./unseal-vault.sh
```

### From the Instance

SSH to the instance and use the built-in scripts:

```bash
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem ubuntu@<instance-ip>

# Check status
vault-status.sh

# Unseal Vault
vault-unseal.sh

# Seal Vault (lock it)
vault-seal.sh
```

**Note**: The instance scripts automatically use the keys from `/home/ubuntu/vault-keys.json`. To install these scripts, run `./install-vault-scripts.sh` from your local machine.

### Manual Unsealing

If you prefer manual control:

```bash
# SSH to the instance
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem ubuntu@<instance-ip>

# Set Vault address
export VAULT_ADDR=http://127.0.0.1:8200

# Provide 3 unseal keys
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>

# Check status
vault status
```

## Common Operations

### Check Vault Status

**From local machine:**
```bash
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem ubuntu@<instance-ip> "vault-status.sh"
```

**From the instance:**
```bash
vault-status.sh
```

Key status indicators:
- **Initialized**: `true` (configured) or `false` (needs initialization)
- **Sealed**: `true` (locked, needs unsealing) or `false` (ready to use)
- **Unseal Progress**: Shows X/3 keys provided

### Login to Vault

```bash
export VAULT_ADDR=http://<instance-ip>:8200
export VAULT_TOKEN=<root-token>
vault status
```

### Access Vault UI

Open browser to: `http://<instance-ip>:8200`

Login with:
- **Method**: Token
- **Token**: Your root token

### Seal Vault (Lock It)

**From the instance:**
```bash
vault-seal.sh
```

**Manual method:**
```bash
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<root-token>
vault operator seal
```

This immediately locks Vault. Requires 3 unseal keys to unlock again.

## Troubleshooting

### Vault is Sealed After Restart

This is normal behavior. Vault always starts sealed. Run `./unseal-vault.sh` to unseal.

### Lost Unseal Keys

**There is no recovery if all keys are lost.** This is by design for security.

Prevention:
- Store keys in multiple secure locations
- Use password manager
- Consider HashiCorp's auto-unseal with cloud KMS for production

### Cannot Access Vault

Check:
1. Service is running: `systemctl status vault`
2. Port is open in security groups (8200)
3. VAULT_ADDR is set correctly
4. Vault is unsealed: `vault status | grep Sealed`

### Vault Performance Issues

For production use, consider:
- Using Consul as storage backend instead of file storage
- Enabling auto-unseal with AWS KMS
- Implementing high availability with multiple Vault instances
- Using Vault Enterprise for advanced features

## Security Best Practices

1. **Never commit credentials to version control**
   - Add `vault-init.json` to `.gitignore`
   - Use secrets management for automation

2. **Use least-privilege access**
   - Create specific policies instead of using root token
   - Implement AppRole or other auth methods
   - Rotate root token regularly

3. **Enable audit logging**
   ```bash
   vault audit enable file file_path=/var/log/vault/audit.log
   ```

4. **Use TLS in production**
   - The current setup uses HTTP for simplicity
   - Production should use HTTPS with valid certificates

5. **Regular backups**
   ```bash
   vault operator raft snapshot save backup.snap
   ```

## Advanced Topics

### Regenerate Root Token

If root token is lost but you have unseal keys:

```bash
vault operator generate-root -init
vault operator generate-root
# Follow prompts with unseal keys
```

### Rotate Unseal Keys

```bash
vault operator rekey -init
vault operator rekey
# Follow prompts to generate new keys
```

### High Availability Setup

For production, deploy multiple Vault instances with:
- Shared storage backend (Consul, AWS DynamoDB)
- Load balancer for distribution
- Auto-unseal with cloud KMS
- Vault Enterprise for replication

## Resources

- [Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Vault Tutorials](https://developer.hashicorp.com/vault/tutorials)
- [Production Hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)
