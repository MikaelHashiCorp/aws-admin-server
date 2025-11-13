# AWS Admin Server - AI Coding Agent Instructions

## General Instruction

DO NOT PUT ANY MATCHED PUBLIC CODE in your response!

## Project Overview
AWS admin server for HashiStack infrastructure management. Primary purposes:
- **Administration**: Manage other AWS instances and infrastructure
- **Build/Deploy Platform**: Launch Packer builds and Terraform deployments
- **HashiStack Environments**: Deploy and manage Consul, Nomad, and Vault clusters

**Technology Stack:**
- Infrastructure: Terraform (following HashiCorp best practices)
- Server OS: Ubuntu 24.04
- Instance Type: t3a.medium (default, configurable)
- Development Platform: macOS Sequoia (15.1) on Apple Silicon

## Terraform Project Structure

```
terraform/
├── modules/                    # Reusable Terraform modules
│   ├── instances.tf           # EC2 instance configuration
│   ├── sg.tf                  # Security group rules
│   ├── iam.tf                 # IAM roles and policies
│   ├── outputs.tf             # Module outputs
│   ├── templates.tf           # Template data sources (user-data, etc.)
│   └── variables.tf           # Module variables
└── control/                   # Terraform control/runtime directory
    ├── .terraform/            # Terraform provider cache (gitignored)
    ├── terraform.tfstate      # State file (gitignored, use remote state in prod)
    ├── main.tf                # Root module calling other modules
    └── terraform.tfvars       # Variable values (gitignored for sensitive data)
```

**terraform.tfvars Variables:**
- `region` - AWS region
- `availability_zones` - List of AZs
- `key_name` - SSH PEM key name
- `owner_name` - Owner identifier
- `owner_email` - Owner contact
- `instance_name` - EC2 instance name tag
- `server_instance_type` - Instance type (default: t3a.medium)
- `allowlist_ip` - IP for SSH access (auto-detects current IP if empty)

**Required Terraform Outputs:**
- `instance_public_ip` - Public IP address of the EC2 instance
- `instance_id` - AWS instance identifier
- `ssh_key_name` - Name of the SSH key pair used

## Critical Developer Workflows

### Connect to AWS using HashiCorp Doormat

**IMPORTANT**: Always authenticate to AWS via Doormat before running any Terraform or Packer commands.

**CRITICAL**: AWS credentials are session-specific. Once authenticated, **STAY IN THE SAME TERMINAL** for all subsequent commands. Opening a new terminal will lose your credentials and require re-authentication.

authenticate:
```bash
doormat login -f ; eval $(doormat aws export --account <your_doormat_account>) ; curl https://ipinfo.io/ip ; echo ; aws sts get-caller-identity --output table
```

**Note**: Replace `<your_doormat_account>` with your Doormat AWS account name (e.g., `aws_mikael.sikora_test`).

**Verification**: The `aws sts get-caller-identity` command should show your authenticated identity.

**⚠️ REMEMBER**: After authentication, use the same terminal for all AWS/Terraform/Packer commands. Do not switch terminals or run commands that spawn new shells unless you re-authenticate first.

### Pre-flight Validation

Run `./pre-flight-check.sh` before any Terraform/Packer operations to verify:
- AWS authentication status
- Required tools installed (terraform, packer, jq, curl, aws-cli)
- Terraform configuration validity
- Region accessibility

### Terraform Operations

**Enable Verbose Logging for Debugging:**
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log
```

**Standard Workflow:**
```bash
cd terraform/control
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Post-Deployment Validation:**
After deployment, run validation script to verify:
- Instance is running and accessible
- SSH connectivity works
- Required packages installed (jq, network tools, Nomad, Consul, Vault)

## Development Guidelines

### HashiCorp Best Practices (Priority)
- Follow official HashiCorp Terraform style guide
- Use terraform fmt before committing
- Implement remote state for production (S3 + DynamoDB)
- Use data sources over hardcoded values
- Tag all resources consistently (Owner, Environment, ManagedBy)

### Server Configuration

**Required Package Installation (via apt):**
- `jq` - JSON processing
- `net-tools` - Network diagnostics
- `nomad` - HashiCorp Nomad
- `consul` - HashiCorp Consul  
- `vault` - HashiCorp Vault

Install via user-data script in `templates.tf` or configuration management.

### Infrastructure as Code
- Use Terraform modules for reusability and organization
- Separate concerns: networking, compute, IAM, security groups

### Security Best Practices
- Use IAM roles for EC2 instance authentication (no long-lived credentials)
- Implement least-privilege access policies
- Security groups: allow SSH only from allowlist_ip
- Use AWS Systems Manager Session Manager as alternative to SSH
- Secrets management via AWS Secrets Manager or Vault

### Future Implementation Areas
When implementing features, consider:
- **Build Server**: Integration with GitHub Actions or GitLab CI for webhook-triggered builds
- **Deployment Pipeline**: Safe deployment patterns with rollback capabilities
- **Telemetry**: Metrics collection and aggregation strategy
- **Jump Server**: Bastion host patterns with audit logging

## Next Steps
1. Define infrastructure requirements and select IaC tool
2. Set up basic AWS networking (VPC, subnets, security groups)
3. Provision compute instance with monitoring
4. Implement first use case (build server or deployment pipeline)
