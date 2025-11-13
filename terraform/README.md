# AWS Admin Server - Terraform Infrastructure

This directory contains the Terraform configuration for deploying the AWS admin server.

## Directory Structure

```
terraform/
├── modules/                    # Reusable Terraform modules
│   ├── instances.tf           # EC2 instance configuration
│   ├── sg.tf                  # Security group rules
│   ├── iam.tf                 # IAM roles and policies
│   ├── outputs.tf             # Module outputs
│   ├── templates.tf           # Template data sources
│   ├── variables.tf           # Module variables
│   └── templates/
│       └── user-data.sh       # Instance initialization script
└── control/                   # Terraform control/runtime directory
    ├── main.tf                # Root module
    ├── variables.tf           # Root variables
    ├── outputs.tf             # Root outputs
    ├── terraform.tfvars       # Your configuration (create from example)
    └── terraform.tfvars.example  # Example configuration
```

## Prerequisites

1. **AWS Authentication**: Authenticate via Doormat before running Terraform
   ```bash
   doormat login -f
   eval $(doormat aws export --account <your_doormat_account>)
   aws sts get-caller-identity
   ```

2. **Required Tools**:
   - Terraform >= 1.5.0
   - AWS CLI v2
   - Valid SSH key pair in AWS

3. **Pre-flight Check**: Run validation script
   ```bash
   ./pre-flight-check.sh
   ```

## Quick Start

1. **Create configuration file**:
   ```bash
   cd terraform/control
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars**:
   - Set your AWS region
   - Configure SSH key name
   - Add owner information
   - Optionally set allowlist_ip (auto-detects if empty)

3. **Enable verbose logging** (recommended):
   ```bash
   export TF_LOG=DEBUG
   export TF_LOG_PATH=terraform-debug.log
   ```

4. **Initialize Terraform**:
   ```bash
   terraform init
   ```

5. **Plan deployment**:
   ```bash
   terraform plan -out=tfplan
   ```

6. **Apply configuration**:
   ```bash
   terraform apply tfplan
   ```

7. **Validate deployment**:
   ```bash
   cd ../..
   ./validate-instance.sh
   ```

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `region` | AWS region | - | Yes |
| `availability_zones` | List of AZs | - | Yes |
| `key_name` | SSH key pair name | - | Yes |
| `owner_name` | Owner identifier | - | Yes |
| `owner_email` | Owner contact | - | Yes |
| `instance_name` | EC2 instance name | - | Yes |
| `server_instance_type` | Instance type | `t3a.medium` | No |
| `allowlist_ip` | SSH access IP (CIDR) | Auto-detected | No |

## Outputs

After successful deployment, Terraform outputs:
- `instance_id` - EC2 instance identifier
- `instance_public_ip` - Public IP address
- `instance_private_ip` - Private IP address
- `ssh_key_name` - SSH key pair name
- `security_group_id` - Security group ID
- `iam_role_name` - IAM role name
- `ssh_connection_string` - SSH command
- `next_steps` - Post-deployment instructions

## Installed Software

The instance comes pre-installed with:
- **HashiCorp Tools**: Consul, Nomad, Vault, Terraform, Packer
- **AWS Tools**: AWS CLI v2
- **Utilities**: jq, net-tools, curl, wget, unzip

## Security

- **IAM Role**: Instance uses IAM role for AWS authentication (no credentials)
- **Security Groups**: SSH access restricted to allowlist_ip
- **Encryption**: Root volume encrypted with EBS encryption
- **SSM Access**: Systems Manager enabled for secure access

## Maintenance

### Destroy Infrastructure
```bash
cd terraform/control
terraform destroy
```

### Update Infrastructure
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Format Code
```bash
terraform fmt -recursive
```

### Validate Configuration
```bash
terraform validate
```

## Troubleshooting

### Check Authentication
```bash
aws sts get-caller-identity
```

### View Debug Logs
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log
terraform plan
cat terraform-debug.log
```

### SSH Connection Issues
1. Verify security group allows your IP
2. Check instance is running: `aws ec2 describe-instances --instance-ids <id>`
3. Verify SSH key permissions: `chmod 400 ~/.ssh/<key>.pem`
4. Use validation script: `./validate-instance.sh`

## Best Practices

- Always run `terraform plan` before `apply`
- Use `terraform fmt` before committing
- Keep sensitive data out of version control
- Use remote state for production deployments
- Tag all resources consistently
- Enable verbose logging for debugging
