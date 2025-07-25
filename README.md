# Octopus Deploy on Kubernetes

This repository provides an automated installation script to deploy Octopus Deploy on Kubernetes using Helm charts.

## Overview

The `install.sh` script automates the complete setup of Octopus Deploy on a Kubernetes cluster, including:
- Octopus Server deployment
- SQL Server database (using mssql-linux)
- Tentacle agent registration
- Port forwarding for local access

## Prerequisites

Before running the installation script, ensure you have:

1. **Kubernetes cluster** - A running Kubernetes cluster with kubectl configured
2. **Helm 3.x** - Helm package manager installed and configured
3. **OpenSSL** - For generating the master key
4. **kubectl** - Kubernetes command-line tool configured to access your cluster

## Installation

### Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/oopsdeploy/octopus-deploy-k8s.git
   cd octopus-deploy-k8s
   ```

2. Make the script executable:
   ```bash
   chmod +x install.sh
   ```

3. Run the installation:
   ```bash
   ./install.sh
   ```

4. When prompted, enter your Octopus API Key for Tentacle registration

## What the Script Does

The `install.sh` script performs the following steps:

### Step 1: Helm Repository Setup
- Adds the official Octopus Deploy Helm repository
- Updates the local Helm repository cache

### Step 2: Namespace Creation
- Creates the `octopus` namespace in Kubernetes
- Skips creation if the namespace already exists

### Step 3: Security Configuration
- Generates a secure master key using OpenSSL
- Creates base64-encoded 32-character master key for Octopus encryption

### Step 4: Octopus Server Configuration
Creates `octopus-values.yaml` with:
- **Image**: Latest Octopus Deploy server image
- **Credentials**: Default admin user with password `Password01!`
- **EULA**: Automatically accepts the End User License Agreement
- **Database**: Configures SQL Server 2019 Linux container
- **Master Key**: Uses the generated encryption key

### Step 5: Octopus Server Deployment
- Installs Octopus Deploy using the official Helm chart
- Deploys to the `octopus` namespace
- Uses the custom values configuration

### Step 6: Service Readiness
- Waits for the Octopus web deployment to be ready
- Sets up port forwarding from localhost:8080 to the Octopus web interface

### Step 7: Tentacle Configuration
- Prompts for Octopus API Key (required for agent registration)
- Creates `tentacle-values.yaml` with:
  - Server URL pointing to the internal Kubernetes service
  - Development environment configuration
  - Worker role assignment
  - EULA acceptance

### Step 8: Tentacle Deployment
- Installs the Linux Tentacle agent using Helm
- Registers the agent with the Octopus Server
- Configures it as a worker in the Dev environment

## Access and Usage

After successful installation:

1. **Web Interface**: Access Octopus Deploy at `http://localhost:8080`
2. **Default Credentials**: 
   - Username: `admin`
   - Password: `Password01!`
3. **Tentacle**: Check the Octopus UI for the registered Tentacle agent

## Configuration Files

The script generates two configuration files:

- `octopus-values.yaml` - Octopus Server Helm values
- `tentacle-values.yaml` - Tentacle agent Helm values

## Security Considerations

⚠️ **Important Security Notes**:

1. **Change Default Password**: The script uses a default password (`Password01!`) - change this immediately after installation
2. **Master Key**: Store the generated master key securely - it's required for data encryption
3. **API Key**: Use a dedicated API key with minimal required permissions
4. **Network Access**: Consider network policies and ingress configuration for production use

## Troubleshooting

### Common Issues

1. **Namespace Already Exists**: This is normal - the script handles existing namespaces gracefully
2. **Port 8080 in Use**: Stop other services using port 8080 or modify the port-forward command
3. **Helm Repository Issues**: Ensure you have internet connectivity and Helm is properly installed
4. **kubectl Access**: Verify your kubectl configuration with `kubectl cluster-info`

### Useful Commands

```bash
# Check deployment status
kubectl get pods -n octopus

# View Octopus logs
kubectl logs deployment/octopus-web -n octopus

# Check Tentacle status
kubectl get pods -l app=linux-tentacle -n octopus

# Stop port forwarding
pkill -f "kubectl port-forward"
```

## Cleanup

To remove the Octopus Deploy installation:

```bash
# Uninstall Helm releases
helm uninstall octopus -n octopus
helm uninstall mytentacle -n octopus

# Delete namespace (optional)
kubectl delete namespace octopus

# Remove configuration files
rm -f octopus-values.yaml tentacle-values.yaml
```

## Terraform Configuration

This repository includes Terraform configuration files in the `terraform/` directory to manage your Octopus Deploy instance using Infrastructure as Code.

### Quick Start with Terraform

1. **Generate an API Key** in your Octopus Deploy web interface (`http://localhost:8080`)
2. **Navigate to the terraform directory**:
   ```bash
   cd terraform
   ```
3. **Configure your variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars and add your API key
   ```
4. **Initialize and apply**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

See the [terraform/README.md](terraform/README.md) for detailed instructions.

## License

This project is provided as-is. Please review Octopus Deploy's licensing terms before use.