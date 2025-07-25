# Octopus Deploy Terraform Configuration

This directory contains Terraform configuration files to manage your Octopus Deploy instance using Infrastructure as Code.

## Prerequisites

1. **Terraform installed** - [Download Terraform](https://www.terraform.io/downloads.html)
2. **Running Octopus Deploy instance** - Use the `../install.sh` script to deploy Octopus to Kubernetes
3. **Octopus API Key** - Generate an API key from the Octopus web interface

## Getting Started

### 1. Create API Key

1. Access your Octopus Deploy instance at `http://localhost:8080`
2. Login with credentials: `admin` / `Password01!`
3. Go to **Configuration** → **Users** → **admin** → **API Keys**
4. Create a new API key and copy it

### 2. Configure Variables

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` and add your API key:
   ```hcl
   octopus_api_key = "API-XXXXXXXXXXXXXXXXXXXXXXXXXX"
   ```

### 3. Initialize and Apply

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Plan the changes:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

## What This Configuration Creates

- **Environments**: Development, Test, and Production environments
- **Project Group**: A project group for organizing projects
- **Lifecycle**: A default lifecycle with retention policies

## Configuration Files

- `versions.tf` - Terraform and provider version constraints
- `provider.tf` - Octopus Deploy provider configuration
- `variables.tf` - Input variable definitions
- `main.tf` - Main resource definitions
- `outputs.tf` - Output value definitions
- `terraform.tfvars.example` - Example variable values
- `.gitignore` - Git ignore rules for Terraform files

## Customization

You can customize the configuration by modifying the variables in `terraform.tfvars`:

- `environment_names` - List of environments to create
- `project_group_name` - Name of the project group
- `octopus_space_id` - Space ID to manage (default is "Spaces-1")

## Security Notes

- The `terraform.tfvars` file contains sensitive information and is ignored by git
- Never commit API keys to version control
- Consider using environment variables or a secrets management system for production use

## Next Steps

After applying this configuration, you can extend it to create:
- Projects
- Deployment processes
- Variables
- Tenants
- And more Octopus Deploy resources

Refer to the [Octopus Deploy Terraform Provider documentation](https://registry.terraform.io/providers/OctopusDeployLabs/octopusdeploy/latest/docs) for all available resources.
