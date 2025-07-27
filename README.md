# Octopus Deploy Kubernetes Demo

This repository demonstrates deploying Octopus Deploy on Kubernetes using Infrastructure as Code (Terraform) with a two-phase approach.

## 🎯 Demo Highlights

- **kubectl Persistence**: Init container ensures kubectl survives pod restarts
- **Native Kubernetes Deployments**: No problematic StatefulSets, uses proper Deployments
- **Two-Phase Deployment**: Infrastructure first, then Octopus configuration
- **Kubernetes Agent**: Automated tentacle deployment with proper service communication
- **Complete IaC**: Everything managed through Terraform

## 📋 Prerequisites

- **Docker Desktop** with Kubernetes enabled
- **kubectl** configured and connected to your cluster
- **Terraform** >= 1.5.0
- **Helm** >= 3.0
- **curl** (for API health checks)

## 🚀 Quick Start

### Option 1: Automated Demo Script

```bash
# Clone the repository
git clone <repository-url>
cd octopus-deploy-k8s

# Run the automated demo
./demo.sh
```

The script will:
1. ✅ Check all prerequisites
2. 🧹 Optionally clean up existing resources
3. 🏗️ Deploy Phase 1 (Infrastructure)
4. ⏳ Wait for Octopus to be ready
5. 🔑 Guide you through API key creation (with automatic terraform.tfvars updates)
6. 🎫 Generate JWT bearer token automatically (no hardcoded values)
7. ⚙️ Deploy Phase 2 (Environments & Agent)
8. 📊 Show final status and access information

### Option 2: Manual Step-by-Step

#### Phase 1: Infrastructure Deployment

```bash
cd terraform

# Disable Octopus provider for Phase 1
sed -i 's/^provider "octopusdeploy"/# provider "octopusdeploy"/' provider.tf

# Deploy infrastructure
terraform init
terraform plan
terraform apply -auto-approve

# Wait for Octopus to be ready
kubectl get pods -n octopus -w
```

#### Phase 2: Octopus Configuration

1. **Access Octopus**: http://localhost (admin/Password01!)
2. **Create API Key**: Profile → API Keys → New API Key
3. **Update Configuration**:

```bash
# Update terraform.tfvars with your API key
octopus_api_key = "API-YOUR-KEY-HERE"
create_octopus_resources = true

# Re-enable Octopus provider
sed -i 's/^# provider "octopusdeploy"/provider "octopusdeploy"/' provider.tf

# Deploy Phase 2
terraform init
terraform plan
terraform apply -auto-approve
```

## 🏗️ Architecture

### Phase 1: Infrastructure
- **Octopus Deploy**: Custom deployment with kubectl init container
- **SQL Server**: Native Kubernetes deployment
- **Persistent Volumes**: For kubectl tools, logs, repository, artifacts
- **Services**: LoadBalancer for web (80) and tentacle (10943)
- **RBAC**: Service account with cluster-wide permissions

### Phase 2: Octopus Configuration  
- **Environments**: Development, Test, Production
- **Lifecycle**: Terraform Managed Lifecycle with proper phases
- **Project Group**: For organizing projects
- **Kubernetes Agent**: Tentacle deployed via Helm chart
- **Service Account Token**: For cluster authentication

## 🔧 Key Technical Features

### kubectl Persistence Solution
```yaml
initContainers:
- name: kubectl-installer
  image: alpine:latest
  command: ["sh", "-c"]
  args:
    - |
      echo "Installing kubectl v1.28.0..."
      apk add --no-cache curl
      mkdir -p /shared/bin
      curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
      chmod +x kubectl
      mv kubectl /shared/bin/kubectl
```

### Proper Service Communication
The Kubernetes Agent connects to the internal tentacle service:
```yaml
serverCommsAddresses: ["tcp://octopus-tentacle.octopus.svc.cluster.local:10943"]
```

## 📊 Verification Commands

```bash
# Check all resources
kubectl get all -n octopus
kubectl get all -n octopus-agent-docker-desktop

# Test kubectl persistence
kubectl exec -n octopus deployment/octopus -- /shared/bin/kubectl version --client

# Check Octopus API
curl http://localhost/api/octopusservernodes/ping

# View Terraform outputs
cd terraform && terraform output
```

## 🧹 Cleanup

### Option 1: Comprehensive Cleanup Script (Recommended)

```bash
# Run the comprehensive cleanup script
./cleanup.sh
```

This script performs a 6-step cleanup process:
1. **Terraform Destroy**: Attempts to destroy managed resources
2. **Namespace Cleanup**: Force removes all pods, deployments, services, secrets, configmaps, and PVCs
3. **Persistent Volume Cleanup**: Removes orphaned PVs with finalizer patching
4. **Cluster Resource Cleanup**: Removes cluster roles and bindings
5. **Helm Release Cleanup**: Removes any remaining Helm releases
6. **Verification**: Confirms complete cleanup

### Option 2: Manual Terraform Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

## 🎬 Demo Script Features

The `demo.sh` script includes:
- ✅ **Prerequisites checking**: Validates all required tools
- 🎨 **Colored output**: Easy-to-follow progress indication  
- ⏱️ **Smart waiting**: Waits for pods and API readiness
- 🛡️ **Error handling**: Exits safely on any errors
- 🧹 **Cleanup option**: Optionally removes existing resources
- 📖 **Step-by-step guidance**: Clear instructions for API key creation
- � **Automatic Updates**: Updates terraform.tfvars with API key and bearer token
- 🎫 **JWT Generation**: Automated bearer token generation with proper parameter passing
- �📊 **Final status**: Shows complete deployment information

### Additional Scripts

- **`cleanup.sh`**: Comprehensive cleanup script for complete resource removal
- **`generate_agent_bearer_token.sh`**: JWT bearer token generation with API key parameter

## 🐛 Troubleshooting

### Common Issues

1. **"cannot re-use a name that is still in use"**
   - Solution: Run cleanup or manually delete conflicting Helm releases

2. **Octopus pod not ready**
   - Check: `kubectl describe pod -n octopus <pod-name>`
   - Common cause: SQL Server not ready yet

3. **Kubernetes Agent connection issues**
   - Verify: Service addresses in Phase 2 configuration
   - Check: `kubectl logs -n octopus-agent-docker-desktop <agent-pod>`

### Manual Cleanup Commands
```bash
# Remove all resources
kubectl delete namespace octopus octopus-agent-docker-desktop
helm uninstall csi-driver-nfs -n kube-system
```

## 📝 Files Structure

```
octopus-deploy-k8s/
├── demo.sh                     # Automated demo script with full workflow
├── cleanup.sh                  # Comprehensive cleanup script (6-step process)
├── generate_agent_bearer_token.sh  # JWT bearer token generation script
├── README.md                   # This file
├── BEARER_TOKEN_GUIDE.md       # Bearer token generation guide
├── octopus-deployment.yaml     # Octopus deployment template
└── terraform/
    ├── main.tf                 # Main Terraform configuration
    ├── phase1.tf              # Infrastructure resources
    ├── phase2.tf              # Octopus configuration resources
    ├── variables.tf           # Variable definitions
    ├── outputs.tf             # Output definitions
    ├── provider.tf            # Provider configurations
    ├── terraform.tfvars       # Configuration values (auto-updated by demo.sh)
    └── versions.tf            # Provider version constraints
```

## 🎯 Demo Points to Highlight

1. **Infrastructure as Code**: Everything is reproducible and version-controlled
2. **kubectl Persistence**: Survives pod restarts (unique solution)
3. **Native Kubernetes**: No StatefulSets, uses proper Deployments
4. **Two-Phase Approach**: Clean separation of infrastructure and configuration
5. **Service Mesh Ready**: Proper internal service communication
6. **Production Ready**: RBAC, persistent storage, health checks
7. **Full Automation**: API key and bearer token handling with zero hardcoded values
8. **Comprehensive Cleanup**: Complete resource removal with finalizer handling
9. **JWT Authentication**: Proper bearer token generation and management

---

**Ready to demo?** Run `./demo.sh` and showcase your Infrastructure as Code expertise! 🚀