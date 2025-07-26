# Octopus Deploy on Kubernetes

This repository provides a complete Infrastructure as Code solution for deploying Octopus Deploy on Kubernetes using Terraform, with **Kubernetes Agent** support for modern container deployments.

## 🚀 Quick Start

Choose your preferred deployment method:

### Option 1: Automated Installation Script (Recommended for Testing)
```bash
git clone <repository-url>
cd octopus-deploy-k8s
chmod +x install.sh
./install.sh
```

### Option 2: Terraform Infrastructure as Code (Recommended for Production)
```bash
git clone <repository-url>
cd octopus-deploy-k8s/terraform
terraform init
terraform apply
```

Both approaches deploy the same infrastructure with:
- ✅ **Octopus Deploy Server** with SQL Server backend
- ✅ **Kubernetes Agent** with kubectl auto-installation
- ✅ **Service Account Authentication** using RBAC
- ✅ **Three Environments** (Development, Test, Production)
- ✅ **Modern Deployment Target** using Kubernetes API

## 📋 Prerequisites

Before starting, ensure you have:
- **Kubernetes cluster** (Docker Desktop works great)
- **kubectl** configured and connected to your cluster
- **Terraform ≥ 1.0** - [Download Terraform](https://www.terraform.io/downloads.html)
- **Helm 3.x** - [Install Helm](https://helm.sh/docs/intro/install/)

## 🤖 Automated Installation Script

The `install.sh` script provides a fully automated deployment experience:

### Features
- 🔄 **Complete Automation** - No manual steps required
- 🎨 **Colored Output** - Easy to follow progress
- ⚡ **Smart Resumption** - Can be restarted safely
- 🔑 **Interactive Prompts** - Guides you through API key and bearer token setup
- ✅ **Verification** - Checks prerequisites and deployment status

### What It Does

1. **Phase 1: Infrastructure Deployment**
   - Deploys Octopus server and SQL database
   - Creates Kubernetes namespace and RBAC
   - Installs kubectl in Octopus container

2. **Interactive Setup**
   - Prompts for API key creation (with skip if already configured)
   - Guides through bearer token generation for Kubernetes Agent

3. **Phase 2: Octopus Configuration**
   - Creates environments and project groups
   - Deploys CSI Driver NFS (required dependency)
   - Installs official Kubernetes Agent using Helm

### Usage
```bash
# First time run
./install.sh

# If you need to restart (it will skip already configured items)
./install.sh

# Clean reinstall (destroy everything first)
cd terraform && terraform destroy && cd .. && ./install.sh
```

## 🏗️ Terraform Infrastructure as Code

For production deployments, use the Terraform configuration directly:

### Two-Phase Deployment

The deployment uses a two-phase approach to solve the chicken-and-egg problem of needing an API key from a system that doesn't exist yet:

#### Phase 1: Infrastructure
```bash
cd terraform
terraform init
cp terraform.tfvars.example terraform.tfvars
terraform apply -var="create_octopus_resources=false" -auto-approve
```

#### Phase 2: Configuration
After Phase 1, get an API key from Octopus UI and bearer token, then:
```bash
# Update terraform.tfvars with your keys
terraform apply -auto-approve
```

### Key Configuration Files

- **`terraform/main.tf`** - Infrastructure resources (namespace, Octopus server, SQL)
- **`terraform/phase1.tf`** - Phase 1 specific resources  
- **`terraform/phase2.tf`** - Phase 2 Octopus configuration with Kubernetes Agent
- **`terraform/variables.tf`** - All configurable parameters
- **`terraform/terraform.tfvars`** - Your actual configuration values

## 🎯 Kubernetes Agent Architecture

This deployment uses the modern **Kubernetes Agent** approach:

### ✅ What You Get
- **Direct Kubernetes API Communication** - No separate agent containers
- **Service Account Authentication** - Secure RBAC permissions
- **Auto-kubectl Installation** - kubectl installed in Octopus container
- **CSI Driver NFS** - Required storage driver for Kubernetes Agent
- **Bearer Token Authentication** - Official Octopus authentication method
- **All Environments Connected** - Single target serves Dev/Test/Prod

### 🔧 How It Works
1. **Service Account** created with cluster-wide permissions
2. **Bearer Token** generated from Octopus UI for authentication
3. **CSI Driver NFS** deployed as prerequisite
4. **Kubernetes Agent** deployed via official Helm chart
5. **kubectl** automatically available for Kubernetes operations

## 🌐 Access Information

After deployment:
- **URL**: `http://localhost`
- **Username**: `admin`
- **Password**: `Password01!`

## 📊 What Gets Created

### Infrastructure Resources
- 🏗️ Kubernetes namespace (`octopus`)
- 🐙 Octopus Deploy server (latest version)
- 🗄️ SQL Server 2019 Linux database
- 🔐 Auto-generated master key for encryption
- 🌐 LoadBalancer service for web access

### Octopus Configuration
- 🌍 **Environments**: Development, Test, Production
- 📁 **Project Group**: "Terraform Managed Projects"
- 🔄 **Lifecycle**: With promotion phases and retention policies
- 🎯 **Kubernetes Agent**: Official Helm chart deployment
- 💾 **CSI Driver NFS**: Required storage driver

## 🔧 Useful Commands

```bash
# Check deployment status
kubectl get all -n octopus

# View install script logs
./install.sh 2>&1 | tee install.log

# Terraform operations
cd terraform
terraform show              # View current state
terraform output           # Show outputs
terraform plan             # Preview changes
terraform destroy         # Clean everything

# Troubleshooting
kubectl logs -f statefulset/octopus -n octopus
kubectl describe pod octopus-0 -n octopus
```

## 🚨 Troubleshooting

### Common Issues

1. **kubectl missing in Octopus container**:
   ```bash
   ./kubectl-install.sh
   ```

2. **Kubernetes Agent health check failing**:
   ```bash
   # Check bearer token is configured
   grep octopus_bearer_token terraform/terraform.tfvars
   
   # Verify CSI Driver NFS is running
   kubectl get pods -n kube-system | grep csi-nfs
   
   # Check Kubernetes Agent pod
   kubectl get pods -n octopus | grep kubernetes-agent
   ```

3. **Port conflicts**:
   - Make sure port 80 is available (not used by other services)
   - Check with: `lsof -i :80`

4. **API key issues**:
   - Format: `API-XXXXXXXXXXXXXXXXXXXXXXXXXX`
   - Create in Octopus UI: Configuration → Users → admin → API Keys

5. **Bearer token issues**:
   - Format: `eyJhbGciOiJQUzI1NiIsImtpZCI6Im...`
   - Get from Octopus UI: Infrastructure → Deployment Targets → Add → Kubernetes Agent

## 🏭 Production Considerations

For production deployments:

1. **Security**:
   - Change default admin password
   - Use HTTPS with proper certificates
   - Implement network policies
   - Use specific image tags (not `latest`)

2. **Infrastructure**:
   - Use remote Terraform state (S3, Azure Storage)
   - Implement proper backup strategies
   - Configure monitoring and alerting
   - Use dedicated service accounts with minimal permissions

3. **Configuration**:
   - Customize resource limits and requests
   - Configure persistent storage for SQL Server
   - Set up ingress controllers
   - Implement proper RBAC policies

## 📚 Next Steps

After deployment, you can:

1. **Create Projects** using the configured environments
2. **Deploy Applications** to your Kubernetes cluster
3. **Extend Configuration** with additional Terraform resources
4. **Add More Deployment Targets** for other environments
5. **Configure Teams and Permissions** for your organization

See the [Octopus Deploy documentation](https://octopus.com/docs) and [Terraform Provider docs](https://registry.terraform.io/providers/OctopusDeployLabs/octopusdeploy/latest/docs) for more advanced configurations.

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch  
3. Test your changes thoroughly
4. Submit a pull request

## 📄 License

This project is provided as-is. Please review Octopus Deploy's licensing terms before use.
   ```

3. **Install kubectl in Octopus** (for Kubernetes deployment targets):
   ```bash
   cd ..
   ./kubectl-install.sh
   ```

4. **Access Octopus Deploy**:
   - URL: `http://localhost`
   - Username: `admin`
   - Password: `Password01!`

## Terraform Deployment (Recommended)

### Why Two Phases?

The deployment is split into two phases to solve a **chicken-and-egg problem**:

- **Phase 1** deploys the Octopus infrastructure but requires no API key
- **Phase 2** configures Octopus resources but requires an API key from a running Octopus instance

This approach allows you to:
1. ✅ Deploy Octopus without needing credentials that don't exist yet
2. ✅ Generate API keys from the running instance
3. ✅ Apply additional configuration using Infrastructure as Code
4. ✅ Keep everything in version control and reproducible
5. ✅ Automatically configure Kubernetes Agent with proper permissions

### Prerequisites

Before starting, ensure you have:

1. **Kubernetes cluster** - A running cluster with kubectl configured (Docker Desktop works great)
2. **Terraform ≥ 1.0** - [Download Terraform](https://www.terraform.io/downloads.html)
3. **Helm 3.x** - [Install Helm](https://helm.sh/docs/intro/install/)
4. **kubectl** - Kubernetes command-line tool configured

### Phase 1: Infrastructure Deployment

Phase 1 deploys the core infrastructure including automatic kubectl installation for Kubernetes Agent functionality.

1. **Clone and navigate to the project**:
   ```bash
   git clone https://github.com/oopsdeploy/octopus-deploy-k8s.git
   cd octopus-deploy-k8s/terraform
   ```
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Configure variables** (optional - defaults work fine):
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if you want to customize settings
   ```

4. **Deploy Phase 1 infrastructure**:
   ```bash
   terraform apply -target=random_password.octopus_master_key -target=kubernetes_namespace.octopus -target=helm_release.octopus_server -auto-approve
   ```

5. **Wait for deployment** (3-5 minutes):
   ```bash
   kubectl get pods -n octopus -w
   ```

6. **Access Octopus Deploy** at `http://localhost`:
   - Username: `admin`
   - Password: `Password01!` (or your custom password)

**What Phase 1 Creates:**
- 🏗️ Kubernetes namespace (`octopus`)
- 🔐 Randomly generated master key for encryption
- 🐙 Octopus Deploy server (latest version)
- 🗄️ SQL Server 2019 Linux database
- 🌐 LoadBalancer service (accessible at `http://localhost`)

### Phase 2: Octopus Configuration

Phase 2 configures Octopus Deploy resources including the Kubernetes deployment target using the Terraform provider.

1. **Generate an API Key** in Octopus Deploy:
   - Login to `http://localhost` with `admin` / `Password01!`
   - Go to **Configuration** → **Users** → **admin** → **API Keys**
   - Create a new API key and copy it

2. **Update configuration**:
   ```bash
   # Edit terraform.tfvars and update:
   octopus_api_key = "API-YOUR-ACTUAL-KEY-HERE"
   create_octopus_resources = true
   ```

3. **Deploy Phase 2 configuration**:
   ```bash
   terraform apply -target=octopusdeploy_environment.environments -target=octopusdeploy_project_group.main -target=octopusdeploy_lifecycle.main -target=octopusdeploy_token_account.kubernetes_service_account -target=octopusdeploy_kubernetes_cluster_deployment_target.docker_desktop -auto-approve
   ```

4. **Verify Kubernetes Agent health**:
   ```bash
   # The deployment target should show as "Healthy" in Octopus UI
   # Or check via API:
   curl -H "X-Octopus-ApiKey: YOUR-API-KEY" http://localhost/api/machines
   ```

**What Phase 2 Creates:**
- 🌍 **Environments**: Development, Test, Production
- 📁 **Project Group**: "Terraform Managed Projects"
- 🔄 **Lifecycle**: With retention policies and promotion phases
- 🎯 **Kubernetes Deployment Target**: "docker-desktop" connected to all environments
- 🔐 **Service Account Token**: Secure authentication for Kubernetes API
- 📊 **Outputs**: Environment IDs, project group, and deployment target information

### Kubernetes Agent Details

The deployment automatically sets up a **Kubernetes Agent** which provides:

✅ **Automatic kubectl Installation**: kubectl is installed in the Octopus server container during deployment
✅ **Service Account Authentication**: Uses RBAC with a dedicated service account (`octopus-deploy`)
✅ **Internal Cluster Access**: Uses `https://kubernetes.default.svc.cluster.local:443` for optimal performance
✅ **Full Kubernetes Permissions**: Cluster role with comprehensive resource access
✅ **All Environments Connected**: Single deployment target serves Dev, Test, and Production
✅ **Health Monitoring**: Automatic health checks ensure connectivity

### Configuration Options

Key variables you can customize in `terraform.tfvars`:

```hcl
# Infrastructure settings
namespace = "octopus"
octopus_admin_username = "admin"
octopus_admin_password = "Password01!"
octopus_image_tag = "latest"
sqlserver_image_tag = "2019-latest"

# Phase 2 configuration
octopus_server_url = "http://localhost"
octopus_api_key = "API-YOUR-KEY-HERE"
create_octopus_resources = true
environment_names = ["Development", "Test", "Production"]
project_group_name = "Terraform Managed Projects"

# Kubernetes deployment target configuration
kubernetes_cluster_url = "https://kubernetes.default.svc.cluster.local:443"  # Internal cluster URL for Kubernetes Agent
kubernetes_skip_tls_verification = true  # Set to false for production with proper certs
kubernetes_worker_pool_id = ""  # Empty for default worker pool
```

### Useful Commands

```bash
# Check deployment status
kubectl get all -n octopus

# View Terraform state
terraform show

# Get sensitive outputs (like master key)
terraform output -json

# Plan changes before applying
terraform plan

# Destroy everything and start fresh
terraform destroy
```

### Complete Destroy and Recreate Process

To completely destroy and recreate the entire setup:

1. **Destroy all Terraform resources**:
   ```bash
   terraform destroy -auto-approve
   ```

2. **Clean up any remaining resources** (if needed):
   ```bash
   kubectl delete namespace octopus --ignore-not-found=true
   helm uninstall octopus -n octopus --ignore-not-found=true
   ```

3. **Recreate from scratch**:
   ```bash
   # Phase 1: Infrastructure
   terraform apply -target=random_password.octopus_master_key -target=kubernetes_namespace.octopus -target=kubernetes_service_account.octopus_deploy -target=kubernetes_cluster_role.octopus_deploy -target=kubernetes_cluster_role_binding.octopus_deploy -target=kubernetes_secret.octopus_deploy_token -target=helm_release.octopus_server -auto-approve
   
   # Wait for Octopus to be ready
   kubectl wait --for=condition=ready pod -l app=octopus -n octopus --timeout=300s
   
   # Get API key from running instance, then update terraform.tfvars
   
   # Phase 2: Configuration
   terraform apply -target=octopusdeploy_environment.environments -target=octopusdeploy_project_group.main -target=octopusdeploy_lifecycle.main -target=octopusdeploy_token_account.kubernetes_service_account -target=octopusdeploy_kubernetes_cluster_deployment_target.docker_desktop -auto-approve
   ```

4. **Verify everything is working**:
   ```bash
   # Check all resources
   terraform output
   
   # Check Kubernetes deployment target health
   kubectl get pods -n octopus
   
   # Access Octopus at http://localhost
   ```

## Shell Script Deployment (Legacy)

The original `install.sh` script is still available for quick testing:

### Quick Start with Shell Script

1. **Clone the repository**:
   ```bash
   git clone https://github.com/oopsdeploy/octopus-deploy-k8s.git
   cd octopus-deploy-k8s
   ```

2. **Run the installation**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Access Octopus Deploy** at `http://localhost:8080`:
   - Username: `admin`
   - Password: `Password01!`

### What the Shell Script Does

The `install.sh` script performs these steps:
1. **Helm Repository Setup** - Adds Octopus Helm repository
2. **Namespace Creation** - Creates `octopus` namespace
3. **Master Key Generation** - Creates secure encryption key
4. **Octopus Server Deployment** - Installs via Helm with SQL Server
5. **Port Forwarding** - Sets up access to web interface
6. **Tentacle Configuration** - Optionally deploys agent

## Comparison: Terraform vs Shell Script

| Feature | Terraform | Shell Script |
|---------|-----------|--------------|
| **Reproducibility** | ✅ Perfect | ⚠️ Variable |
| **State Management** | ✅ Full tracking | ❌ None |
| **Rollback Capability** | ✅ Easy | ❌ Manual |
| **Configuration Drift** | ✅ Detects changes | ❌ No detection |
| **Version Control** | ✅ Full support | ⚠️ Limited |
| **Dependency Management** | ✅ Automatic | ❌ Manual ordering |
| **Idempotency** | ✅ Safe re-runs | ⚠️ May cause issues |
| **Production Ready** | ✅ Yes | ❌ Development only |
| **Learning Curve** | ⚠️ Moderate | ✅ Simple |
| **Setup Time** | ⚠️ 5-10 minutes | ✅ 2-3 minutes |

## Troubleshooting

### Common Issues

1. **Port conflicts**: 
   - Terraform uses `http://localhost` (port 80)
   - Shell script uses `http://localhost:8080`

2. **Kubernetes deployment target showing as Unhealthy**:
   ```bash
   # Check if kubectl is available in Octopus container
   kubectl exec -n octopus octopus-0 -- which kubectl
   
   # Check cluster connectivity from within Octopus
   kubectl exec -n octopus octopus-0 -- kubectl cluster-info
   
   # Verify service account permissions
   kubectl auth can-i --list --as=system:serviceaccount:octopus:octopus-deploy
   
   # Trigger manual health check via API
   curl -H "X-Octopus-ApiKey: YOUR-API-KEY" -X POST -H "Content-Type: application/json" -d '{"Name":"Health","Description":"Manual health check","Arguments":{"Timeout":"00:05:00","MachineIds":["Machines-1"]}}' http://localhost/api/tasks
   ```

3. **Kubernetes access**:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

4. **Helm issues**:
   ```bash
   helm repo update
   helm list --all-namespaces
   ```

5. **Check Octopus status**:
   ```bash
   kubectl get pods -n octopus
   kubectl logs -f statefulset/octopus -n octopus
   ```

6. **Service account token issues**:
   ```bash
   # Check if service account token exists
   kubectl get secret octopus-deploy-token -n octopus
   
   # Verify token has content
   kubectl get secret octopus-deploy-token -n octopus -o jsonpath='{.data.token}' | base64 -d | wc -c
   ```

### Recovery Commands

```bash
# Clean up everything
terraform destroy
kubectl delete namespace octopus

# Start fresh
terraform init
terraform apply -target=random_password.octopus_master_key -target=kubernetes_namespace.octopus -target=kubernetes_service_account.octopus_deploy -target=kubernetes_cluster_role.octopus_deploy -target=kubernetes_cluster_role_binding.octopus_deploy -target=kubernetes_secret.octopus_deploy_token -target=helm_release.octopus_server -auto-approve
```

### Kubernetes Agent Specific Troubleshooting

If the Kubernetes deployment target is showing as unhealthy:

1. **Check kubectl installation**:
   ```bash
   kubectl exec -n octopus octopus-0 -- kubectl version --client
   ```

2. **Verify cluster URL**:
   - Internal cluster URL: `https://kubernetes.default.svc.cluster.local:443` ✅
   - External cluster URL: `https://127.0.0.1:6443` ❌ (won't work from inside container)

3. **Test service account permissions**:
   ```bash
   # Test basic connectivity
   kubectl exec -n octopus octopus-0 -- kubectl get nodes
   
   # Test namespace access
   kubectl exec -n octopus octopus-0 -- kubectl get pods -n octopus
   ```

## Security Considerations

⚠️ **Important Security Notes**:

1. **Change default passwords** immediately after deployment
2. **API keys** are stored in Terraform state - secure your state files
3. **Master key** is auto-generated and stored in Terraform state
4. **terraform.tfvars** contains sensitive data and is git-ignored
5. **Use HTTPS** and proper ingress controllers for production
6. **Network policies** should be configured for production environments

## Production Recommendations

For production deployments:

1. **Use remote Terraform state** (S3, Azure Storage, etc.)
2. **Implement proper RBAC** in Kubernetes
3. **Configure ingress controllers** with TLS certificates
4. **Set up monitoring and alerting**
5. **Use dedicated service accounts** with minimal permissions
6. **Implement backup strategies** for Octopus data
7. **Use specific image tags** instead of "latest"

## Next Steps

After deployment, your Octopus Deploy instance includes a fully configured Kubernetes deployment target. You can extend the Terraform configuration to create:

- 📦 **Projects** and deployment processes
- 🔧 **Variables** and variable sets  
- 🎯 **Additional deployment targets** (cloud resources, other Kubernetes clusters)
- 👥 **Teams** and permissions
- 🏢 **Tenants** for multi-tenant deployments
- 📜 **Certificates** and external feeds

### Ready-to-Use Features

Your deployment includes:
- ✅ **Kubernetes deployment target** (`docker-desktop`) connected to all environments  
- ✅ **Service account authentication** with proper RBAC permissions
- ✅ **kubectl integration** for Kubernetes operations
- ✅ **All three environments** (Development, Test, Production)
- ✅ **Project group** for organizing your applications
- ✅ **Lifecycle** with proper promotion workflow

### Sample Kubernetes Deployment

You can now deploy applications to Kubernetes using Octopus Deploy:

1. Create a new project in the "Terraform Managed Projects" group
2. Add deployment steps using the Kubernetes deployment target
3. Deploy to Development → Test → Production using the configured lifecycle

See the [Octopus Deploy Terraform Provider documentation](https://registry.terraform.io/providers/OctopusDeployLabs/octopusdeploy/latest/docs) for all available resources.

## Quick Reference

### Complete Setup from Scratch

```bash
# 1. Clone and setup
git clone https://github.com/oopsdeploy/octopus-deploy-k8s.git
cd octopus-deploy-k8s/terraform
terraform init

# 2. Phase 1: Infrastructure (no API key needed)
terraform apply -target=random_password.octopus_master_key -target=kubernetes_namespace.octopus -target=kubernetes_service_account.octopus_deploy -target=kubernetes_cluster_role.octopus_deploy -target=kubernetes_cluster_role_binding.octopus_deploy -target=kubernetes_secret.octopus_deploy_token -target=helm_release.octopus_server -auto-approve

# 3. Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=octopus -n octopus --timeout=300s

# 4. Access Octopus at http://localhost, create API key, add to terraform.tfvars
# Set: octopus_api_key = "API-YOUR-KEY-HERE" and create_octopus_resources = true

# 5. Phase 2: Configuration (API key required)
terraform apply -target=octopusdeploy_environment.environments -target=octopusdeploy_project_group.main -target=octopusdeploy_lifecycle.main -target=octopusdeploy_token_account.kubernetes_service_account -target=octopusdeploy_kubernetes_cluster_deployment_target.docker_desktop -auto-approve

# 6. Verify deployment target is healthy
terraform output
```

### Key Features Delivered

✅ **Octopus Deploy Server** - Running on Kubernetes with SQL Server backend  
✅ **Kubernetes Agent** - Modern deployment approach with kubectl auto-installed  
✅ **Service Account Authentication** - Secure RBAC permissions for cluster access  
✅ **Three Environments** - Development, Test, Production with proper lifecycle  
✅ **Deployment Target** - "docker-desktop" connected to all environments  
✅ **Project Organization** - Project group and lifecycle for structured deployments  
✅ **Infrastructure as Code** - Everything versioned and reproducible  

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided as-is. Please review Octopus Deploy's licensing terms before use.