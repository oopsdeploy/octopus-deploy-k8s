#!/bin/bash

# Comprehensive Octopus Deploy Installation Script
# This script replaces manual steps with a complete automated deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform"
NAMESPACE="octopus"
KUBECTL_VERSION="v1.28.0"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl is available"
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "terraform is not installed. Please install terraform first."
        exit 1
    fi
    print_success "terraform is available"
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed. Please install helm first."
        exit 1
    fi
    print_success "helm is available"
    
    # Check kubernetes cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    print_success "Kubernetes cluster is accessible"
}

# Function to initialize terraform
initialize_terraform() {
    print_header "INITIALIZING TERRAFORM"
    
    cd "$TERRAFORM_DIR"
    
    print_status "Running terraform init..."
    terraform init
    
    print_success "Terraform initialized"
    cd ..
}

# Function to deploy Phase 1 (Infrastructure)
deploy_phase1() {
    print_header "PHASE 1: DEPLOYING INFRASTRUCTURE"
    
    cd "$TERRAFORM_DIR"
    
    print_status "Creating terraform.tfvars if it doesn't exist..."
    if [[ ! -f terraform.tfvars ]]; then
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Created terraform.tfvars from example. Please review and customize if needed."
    fi
    
    print_status "Deploying Octopus infrastructure..."
    terraform apply -var="create_octopus_resources=false" -auto-approve
    
    print_success "Phase 1 infrastructure deployed"
    cd ..
}

# Function to wait for Octopus to be ready
wait_for_octopus() {
    print_header "WAITING FOR OCTOPUS TO BE READY"
    
    print_status "Waiting for Octopus pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=octopus -n "$NAMESPACE" --timeout=300s
    
    print_status "Waiting for Octopus service to be accessible..."
    max_attempts=30
    attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f http://localhost/api > /dev/null 2>&1; then
            print_success "Octopus Deploy is ready and accessible"
            break
        fi
        
        print_status "Attempt $attempt/$max_attempts - Octopus not ready yet, waiting 10 seconds..."
        sleep 10
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        print_error "Octopus Deploy did not become ready within the timeout period"
        print_status "You can check the status with: kubectl get pods -n $NAMESPACE"
        exit 1
    fi
}

# Function to install kubectl in Octopus container
install_kubectl() {
    print_header "INSTALLING KUBECTL IN OCTOPUS CONTAINER"
    
    print_status "Installing kubectl $KUBECTL_VERSION in octopus-0 pod..."
    
    # Check if octopus pod is running
    if ! kubectl get pod octopus-0 -n "$NAMESPACE" >/dev/null 2>&1; then
        print_error "octopus-0 pod not found in $NAMESPACE namespace"
        kubectl get pods -n "$NAMESPACE"
        exit 1
    fi
    
    # Install kubectl
    kubectl exec -n "$NAMESPACE" octopus-0 -- bash -c "
        curl -LO https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl && 
        chmod +x kubectl && 
        mv kubectl /usr/local/bin/ && 
        kubectl version --client
    "
    
    print_success "kubectl installed successfully in Octopus container"
}

# Function to prompt for API key
get_api_key() {
    print_header "API KEY SETUP"
    
    # Check if API key is already configured
    cd "$TERRAFORM_DIR"
    existing_api_key=$(grep -o 'octopus_api_key = "[^"]*"' terraform.tfvars | sed 's/octopus_api_key = "\(.*\)"/\1/')
    cd ..
    
    if [[ -n "$existing_api_key" && "$existing_api_key" != "YOUR_API_KEY_HERE" && $existing_api_key =~ ^API-.* ]]; then
        print_success "API key already configured: ${existing_api_key:0:10}..."
        return
    fi
    
    print_status "Octopus Deploy is now accessible at: http://localhost"
    print_status "Default credentials:"
    print_status "  Username: admin"
    print_status "  Password: Password01!"
    echo ""
    print_warning "Please follow these steps to create an API key:"
    echo "  1. Open http://localhost in your browser"
    echo "  2. Log in with the credentials above"
    echo "  3. Go to Configuration → Users → admin → API Keys"
    echo "  4. Create a new API key"
    echo "  5. Copy the API key"
    echo ""
    
    read -p "Enter your API key (API-XXXXXX...): " api_key
    
    if [[ ! $api_key =~ ^API-.* ]]; then
        print_error "Invalid API key format. API keys should start with 'API-'"
        exit 1
    fi
    
    # Update terraform.tfvars with API key
    cd "$TERRAFORM_DIR"
    sed -i.bak "s/octopus_api_key = \".*\"/octopus_api_key = \"$api_key\"/" terraform.tfvars
    sed -i.bak "s/create_octopus_resources = false/create_octopus_resources = true/" terraform.tfvars
    
    print_success "API key configured in terraform.tfvars"
    cd ..
}

# Function to get bearer token for Kubernetes Agent
get_bearer_token() {
    print_header "KUBERNETES AGENT BEARER TOKEN SETUP"
    
    # Check if bearer token is already configured
    cd "$TERRAFORM_DIR"
    existing_bearer_token=$(grep -o 'octopus_bearer_token = "[^"]*"' terraform.tfvars | sed 's/octopus_bearer_token = "\(.*\)"/\1/')
    cd ..
    
    if [[ -n "$existing_bearer_token" && "$existing_bearer_token" != "YOUR_BEARER_TOKEN_HERE" && $existing_bearer_token =~ ^eyJ.* ]]; then
        print_success "Bearer token already configured: ${existing_bearer_token:0:20}..."
        return
    fi
    
    print_warning "To deploy a Kubernetes Agent, we need to create a bearer token:"
    echo "  1. In Octopus Deploy (http://localhost), go to Infrastructure → Deployment Targets"
    echo "  2. Click 'Add Deployment Target'"
    echo "  3. Select 'Kubernetes Agent'"
    echo "  4. Follow the setup wizard - it will show you Helm commands"
    echo "  5. From the Helm commands, copy the LONG bearer token (starts with 'eyJ')"
    echo "  6. Don't run the Helm commands manually - just copy the bearer token"
    echo ""
    print_status "Example bearer token format: eyJhbGciOiJQUzI1NiIsImtpZCI6Im..."
    echo ""
    
    read -p "Enter the bearer token from the Octopus UI: " bearer_token
    
    if [[ ! $bearer_token =~ ^eyJ.* ]]; then
        print_error "Invalid bearer token format. Bearer tokens should start with 'eyJ'"
        exit 1
    fi
    
    # Update terraform.tfvars with bearer token
    cd "$TERRAFORM_DIR"
    sed -i.bak "s/octopus_bearer_token = \".*\"/octopus_bearer_token = \"$bearer_token\"/" terraform.tfvars
    
    print_success "Bearer token configured in terraform.tfvars"
    cd ..
}

# Function to deploy Phase 2 (Octopus Configuration)
deploy_phase2() {
    print_header "PHASE 2: DEPLOYING OCTOPUS CONFIGURATION"
    
    cd "$TERRAFORM_DIR"
    
    print_status "Deploying Octopus resources (environments, project groups, deployment targets)..."
    terraform apply -auto-approve
    
    print_success "Phase 2 configuration deployed"
    cd ..
}

# Function to verify deployment
verify_deployment() {
    print_header "VERIFYING DEPLOYMENT"
    
    cd "$TERRAFORM_DIR"
    
    print_status "Getting deployment status..."
    terraform output
    
    print_status "Checking Kubernetes resources..."
    kubectl get all -n "$NAMESPACE"
    
    print_success "Deployment verification complete"
    cd ..
}

# Function to display final instructions
show_final_instructions() {
    print_header "DEPLOYMENT COMPLETE!"
    
    echo -e "${GREEN}🎉 Octopus Deploy has been successfully deployed!${NC}"
    echo ""
    echo -e "${BLUE}Access Information:${NC}"
    echo "  🌐 Web Interface: http://localhost"
    echo "  👤 Username: admin"
    echo "  🔑 Password: Password01!"
    echo ""
    echo -e "${BLUE}What was created:${NC}"
    echo "  ✅ Octopus Deploy server with SQL Server backend"
    echo "  ✅ Kubernetes namespace: $NAMESPACE"
    echo "  ✅ RBAC configuration for Kubernetes deployments"
    echo "  ✅ kubectl automatically installed in Octopus container"
    echo "  ✅ Environments: Development, Test, Production"
    echo "  ✅ CSI Driver NFS for Kubernetes Agent support"
    echo "  ✅ Kubernetes Agent deployment target: $NAMESPACE"
    echo "  ✅ Project group: Terraform Managed Projects"
    echo "  ✅ Lifecycle with retention policies"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  📊 Check pods: kubectl get pods -n $NAMESPACE"
    echo "  🔧 Verify kubectl: kubectl exec -n $NAMESPACE octopus-0 -- kubectl version --client"
    echo "  🏗️  Terraform status: cd terraform && terraform show"
    echo "  🗑️  Destroy everything: cd terraform && terraform destroy"
    echo ""
    echo -e "${YELLOW}Note:${NC} kubectl is automatically installed on every pod restart via init container"
}

# Main execution flow
main() {
    print_header "OCTOPUS DEPLOY AUTOMATED INSTALLATION"
    print_status "Starting comprehensive Octopus Deploy installation..."
    
    check_prerequisites
    initialize_terraform
    deploy_phase1
    wait_for_octopus
    # kubectl is now installed automatically via init container
    get_api_key
    get_bearer_token
    deploy_phase2
    verify_deployment
    show_final_instructions
    
    print_success "Installation completed successfully!"
}

# Handle script interruption
trap 'print_error "Installation interrupted by user"; exit 1' INT

# Run main function
main "$@"
