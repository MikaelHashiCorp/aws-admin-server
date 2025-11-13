# AWS Admin Server

An AWS-hosted administration server for managing HashiStack infrastructure. This server serves as a central platform for launching Packer builds, Terraform deployments, and managing Consul, Nomad, and Vault environments.

## Purpose

- **Administration**: Manage other AWS instances and infrastructure
- **Build/Deploy Platform**: Launch Packer builds and Terraform deployments
- **HashiStack Environments**: Deploy and manage Consul, Nomad, and Vault clusters

## Technology Stack

- **Infrastructure**: Terraform (HashiCorp best practices)
- **Server OS**: Ubuntu 24.04 LTS
- **Instance Type**: t3a.medium (default, configurable)
- **Development Platform**: macOS Sequoia (15.1) on Apple Silicon
- **Pre-installed Tools**: Consul, Nomad, Vault, Terraform, Packer, AWS CLI v2

## Quick Start

### 1. Prerequisites

- **Doormat Access**: HashiCorp Doormat for AWS authentication
- **SSH Key**: Valid SSH key pair in AWS
- **Tools**: Terraform >= 1.5.0, AWS CLI v2

### 2. Authentication

**CRITICAL**: Always authenticate via Doormat before running any commands. Stay in the same terminal session after authentication.

```bash
doormat login -f
eval $(doormat aws export --account <your_doormat_account>)
aws sts get-caller-identity
```

### 3. Pre-flight Check

Run validation before deployment:

```bash
./pre-flight-check.sh
```

### 4. Configure Terraform

```bash
cd terraform/control
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

### 5. Deploy Infrastructure

```bash
# Enable debug logging (recommended)
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log

# Initialize and deploy
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 6. Validate Deployment

```bash
cd ../..
./validate-instance.sh
```

## Project Structure

```
.
├── .github/
│   └── copilot-instructions.md    # AI coding agent instructions
├── terraform/
│   ├── modules/                   # Reusable Terraform modules
│   │   ├── instances.tf          # EC2 configuration
│   │   ├── sg.tf                 # Security groups
│   │   ├── iam.tf                # IAM roles and policies
│   │   ├── outputs.tf            # Module outputs
│   │   ├── templates.tf          # Template data sources
│   │   ├── variables.tf          # Module variables
│   │   └── templates/
│   │       └── user-data.sh      # Instance initialization
│   └── control/                   # Terraform runtime directory
│       ├── main.tf               # Root module
│       ├── variables.tf          # Root variables
│       ├── outputs.tf            # Root outputs
│       └── terraform.tfvars      # Configuration (not in git)
├── pre-flight-check.sh           # Pre-deployment validation
├── validate-instance.sh          # Post-deployment validation
└── README.md                     # This file
```

## Configuration

### Required Variables (terraform.tfvars)

- `region` - AWS region (e.g., "us-east-1")
- `availability_zones` - List of AZs
- `key_name` - SSH key pair name
- `owner_name` - Your name
- `owner_email` - Your email
- `instance_name` - Name tag for the instance
- `server_instance_type` - Instance type (default: t3a.medium)
- `allowlist_ip` - SSH access IP (auto-detects if empty)

### Terraform Outputs

After deployment, you'll receive:
- Instance ID and IP addresses
- SSH connection string
- Security group and IAM role details

## Security

- **IAM Roles**: Instance uses IAM roles (no long-lived credentials)
- **Security Groups**: SSH restricted to allowlist_ip
- **Encryption**: EBS volumes encrypted
- **SSM Access**: AWS Systems Manager enabled for secure access

## Validation Scripts

### pre-flight-check.sh
Validates environment before deployment:
- AWS credentials active
- Required tools installed
- Terraform configuration valid
- AWS region accessible

### validate-instance.sh
Validates deployment after Terraform apply:
- Instance running and accessible
- SSH connectivity working
- Required packages installed
- OS version correct

## Installed Software

The instance includes:
- **HashiCorp**: Consul, Nomad, Vault, Terraform, Packer
- **AWS Tools**: AWS CLI v2
- **Utilities**: jq, net-tools, curl, wget, unzip

## Development Workflow

1. Authenticate via Doormat (stay in same terminal)
2. Run pre-flight check
3. Configure terraform.tfvars
4. Enable verbose logging (TF_LOG=DEBUG)
5. Initialize Terraform
6. Plan and review changes
7. Apply configuration
8. Run validation script
9. Connect via SSH

## Troubleshooting

### Authentication Issues
```bash
# Re-authenticate with Doormat
doormat login -f
eval $(doormat aws export --account <your_account>)
aws sts get-caller-identity
```

### SSH Connection Issues
```bash
# Check instance state
aws ec2 describe-instances --instance-ids <id>

# Verify SSH key permissions
chmod 400 ~/.ssh/<key>.pem

# Run validation
./validate-instance.sh
```

### Terraform Debug
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log
terraform plan
cat terraform-debug.log
```

## Contributing

Follow HashiCorp Terraform best practices:
- Use `terraform fmt` before committing
- Run `terraform validate` to check syntax
- Keep sensitive data out of git
- Tag all resources consistently

## License

MIT License - See [LICENSE](LICENSE) file for details
