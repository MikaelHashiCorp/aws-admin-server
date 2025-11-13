# Contributing to AWS Admin Server

## Development Setup

1. **Clone the repository**
2. **Install prerequisites**:
   - Terraform >= 1.5.0
   - AWS CLI v2
   - HashiCorp Doormat

3. **Authenticate to AWS**:
   ```bash
   doormat login -f
   eval $(doormat aws export --account <your_account>)
   ```

## Terraform Development

### Code Style

Follow HashiCorp Terraform best practices:

```bash
# Format code before committing
terraform fmt -recursive

# Validate configuration
cd terraform/control
terraform validate
```

### Making Changes

1. **Create a branch** for your changes
2. **Make modifications** to Terraform files
3. **Format code**: `terraform fmt -recursive`
4. **Test locally**: 
   ```bash
   cd terraform/control
   terraform plan
   ```
5. **Commit changes** with descriptive message
6. **Create pull request**

### Directory Structure

Follow the established pattern:
- **terraform/modules/**: Reusable module code
- **terraform/control/**: Runtime configuration
- Module files: `instances.tf`, `sg.tf`, `iam.tf`, `outputs.tf`, `templates.tf`, `variables.tf`

### Variable Naming

- Use snake_case for all variables
- Prefix boolean variables with `enable_` or `is_`
- Add clear descriptions to all variables

### Tagging

All resources must include these tags:
- `Name` - Resource name
- `Owner` - Owner name
- `OwnerEmail` - Owner email
- `Environment` - Environment (development/staging/production)
- `ManagedBy` - Always "terraform"

## Testing

### Pre-flight Check

Run before any Terraform operation:
```bash
./pre-flight-check.sh
```

### Validation

After deployment:
```bash
./validate-instance.sh
```

### Manual Testing

1. Deploy to test environment
2. Verify SSH connectivity
3. Check installed packages
4. Test HashiStack tools (Consul, Nomad, Vault)

## Security Guidelines

- **No credentials in code**: Use IAM roles
- **No sensitive data in git**: Check .gitignore
- **Least privilege**: Minimal IAM permissions
- **Encryption**: All volumes encrypted
- **Access control**: SSH from allowlisted IPs only

## Documentation

### Update When Changing:

- **README.md**: User-facing changes
- **terraform/README.md**: Terraform-specific changes
- **.github/copilot-instructions.md**: AI agent guidance
- **Inline comments**: Complex logic explanations

### Documentation Standards

- Clear, concise language
- Include examples
- Document the "why" not just the "what"
- Keep up-to-date with code changes

## Commit Messages

Follow conventional commits:
```
feat: Add Vault cluster support
fix: Correct security group rules for Consul
docs: Update README with new variables
refactor: Reorganize module structure
```

## Pull Request Process

1. Update documentation
2. Format Terraform code
3. Validate configuration
4. Test in your account
5. Create PR with description
6. Address review feedback

## Need Help?

- Check `.github/copilot-instructions.md` for project overview
- Review HashiCorp Terraform documentation
- Ask in pull request comments
