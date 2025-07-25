# Octopus Deploy Terraform Configuration

This directory contains a complete Terraform configuration that replaces the `../install.sh` script, providing Infrastructure as Code for your entire Octopus Deploy setup on Kubernetes.

## What This Does

This Terraform configuration completely replaces the manual `install.sh` script and provides:

### Phase 1: Infrastructure Deployment
- **Kubernetes Namespace**: Creates the `octopus` namespace
- **Helm Repository**: Automatically adds the Octopus Helm repository
- **Octopus Server**: Deploys Octopus Deploy using Helm
- **SQL Server**: Deploys SQL Server 2019 Linux container
- **Master Key**: Auto-generates a secure master key
- **Admin Credentials**: Configures admin user with specified password

### Phase 2: Octopus Configuration (Optional)
- **Environments**: Creates Development, Test, and Production environments
- **Project Group**: Creates a project group for organizing projects
- **Lifecycle**: Creates a lifecycle with retention policies

## Prerequisites

1. **Terraform installed** - [Download Terraform](https://www.terraform.io/downloads.html)
2. **kubectl configured** - Access to your Kubernetes cluster
3. **Helm installed** - [Install Helm](https://helm.sh/docs/intro/install/)

## Two-Phase Deployment

### Phase 1: Deploy Octopus Infrastructure

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Review and customize** `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if needed (defaults are usually fine)
   ```

3. **Deploy the infrastructure**:
   ```bash
   terraform plan
   terraform apply
   ```

4. **Set up port forwarding**:
   ```bash
   # Use the output command from terraform apply
   kubectl port-forward deployment/octopus-web 8080:80 -n octopus
   ```

5. **Access Octopus Deploy** at `http://localhost:8080`:
   - Username: `admin`
   - Password: `Password01!` (or whatever you set in terraform.tfvars)

### Phase 2: Configure Octopus Resources (Optional)

After Phase 1 is complete and you can access Octopus:

1. **Create an API Key** in Octopus Deploy:
   - Go to Configuration → Users → admin → API Keys
   - Create a new API key

2. **Update terraform.tfvars**:
   ```hcl
   octopus_api_key = "API-XXXXXXXXXXXXXXXXXXXXXXXXXX"
   create_octopus_resources = true
   ```

3. **Apply Phase 2 configuration**:
   ```bash
   terraform plan
   terraform apply
   ```

## Configuration Files

- `versions.tf` - Provider version constraints (Kubernetes, Helm, Octopus, Random)
- `provider.tf` - Provider configurations
- `variables.tf` - All input variables with descriptions
- `main.tf` - Main infrastructure resources
- `outputs.tf` - Useful output values
- `terraform.tfvars.example` - Example configuration
- `terraform.tfvars` - Your actual configuration (git-ignored)

## Key Variables

### Phase 1 Variables
```hcl
namespace = "octopus"                    # Kubernetes namespace
octopus_admin_username = "admin"         # Admin username
octopus_admin_password = "Password01!"   # Admin password
octopus_image_tag = "latest"            # Octopus Docker image tag
sqlserver_image_tag = "2019-latest"     # SQL Server image tag
```

### Phase 2 Variables
```hcl
octopus_api_key = "API-XXX..."          # Your API key
create_octopus_resources = true         # Enable Phase 2
environment_names = ["Dev", "Test", "Prod"]  # Environments to create
project_group_name = "My Projects"      # Project group name
```

## Useful Terraform Commands

```bash
# Initialize (first time only)
terraform init

# See what will change
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List all resources
terraform state list

# Show sensitive outputs (like master key)
terraform output -json

# Destroy everything
terraform destroy
```

## Advantages Over install.sh

✅ **Reproducible**: Exact same setup every time  
✅ **Version Controlled**: Configuration is in git  
✅ **Idempotent**: Safe to run multiple times  
✅ **Rollback**: Easy to revert changes  
✅ **Customizable**: Easy to modify configurations  
✅ **Secure**: Sensitive values handled properly  
✅ **Dependencies**: Automatic resource ordering  
✅ **State Management**: Tracks what was created  

## Migration from install.sh

If you previously used `install.sh`, you can:

1. **Keep existing deployment**: This Terraform config can manage existing resources
2. **Fresh deployment**: Destroy existing resources and deploy with Terraform
3. **Import existing**: Use `terraform import` to bring existing resources under Terraform management

## Troubleshooting

### Common Issues

1. **Kubernetes connection issues**:
   ```bash
   kubectl cluster-info
   ```

2. **Helm repository issues**:
   ```bash
   helm repo list
   helm repo update
   ```

3. **Port forwarding**:
   ```bash
   kubectl get pods -n octopus
   kubectl port-forward deployment/octopus-web 8080:80 -n octopus
   ```

4. **Check deployment status**:
   ```bash
   kubectl get all -n octopus
   kubectl describe deployment octopus-web -n octopus
   ```

### Useful Outputs

After applying, Terraform provides useful outputs:
- Port forward command
- Admin credentials
- Generated master key
- kubectl commands for troubleshooting

## Security Notes

🔒 **Important Security Considerations**:

1. **Change default password** after first login
2. **Master key** is auto-generated and stored in Terraform state
3. **API keys** are marked as sensitive
4. **terraform.tfvars** is git-ignored
5. **Terraform state** may contain sensitive data - secure it appropriately

## Next Steps

After deployment, you can extend this configuration to create:
- Additional projects and deployment processes
- More environments and tenants
- Custom lifecycles and variable sets
- Deployment targets and certificates

See the [Octopus Deploy Terraform Provider documentation](https://registry.terraform.io/providers/OctopusDeployLabs/octopusdeploy/latest/docs) for all available resources.
