#!/bin/bash

# Octopus Deploy Kubernetes Demo Script
# This script demonstrates a complete Infrastructure-as-Code deployment of Octopus Deploy

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

# Check prerequisites
print_header "CHECKING PREREQUISITES"

# Check if we're in the right directory
if [ ! -f "terraform/main.tf" ]; then
    print_error "Please run this script from the octopus-deploy-k8s root directory"
    exit 1
fi

# Check if kubectl is installed and connected
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "terraform is not installed or not in PATH"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Check Kubernetes connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_success "All prerequisites met!"

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        print_warning "Namespace '$namespace' does not exist yet"
        return 1
    fi
    
    print_status "Waiting for pods in namespace '$namespace' to be ready (timeout: ${timeout}s)..."
    
    if kubectl wait --for=condition=ready pod --all -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        print_success "All pods in namespace '$namespace' are ready!"
        return 0
    else
        print_warning "Some pods may not be ready yet, continuing..."
        return 1
    fi
}

# Function to check if Octopus API is responding
wait_for_octopus_api() {
    local timeout=300
    local count=0
    
    print_status "Waiting for Octopus API to respond (timeout: ${timeout}s)..."
    
    while [ $count -lt $timeout ]; do
        if curl -s http://localhost/api/octopusservernodes/ping > /dev/null 2>&1; then
            print_success "Octopus API is responding!"
            return 0
        fi
        sleep 1
        ((count++))
        if [ $((count % 30)) -eq 0 ]; then
            print_status "Still waiting for Octopus API... (${count}s elapsed)"
        fi
    done
    
    print_error "Octopus API did not respond within ${timeout} seconds"
    return 1
}

# Function to check if Phase 1 is already deployed
check_phase1_status() {
    print_status "Checking Phase 1 deployment status..."
    
    if kubectl get namespace octopus &> /dev/null && \
       kubectl get deployment octopus -n octopus &> /dev/null && \
       kubectl get service octopus-web -n octopus &> /dev/null; then
        print_success "Phase 1 infrastructure is already deployed"
        return 0
    else
        print_status "Phase 1 infrastructure needs to be deployed"
        return 1
    fi
}

# Function to check if Phase 2 is already deployed
check_phase2_status() {
    print_status "Checking Phase 2 deployment status..."
    
    if kubectl get namespace octopus-agent-docker-desktop &> /dev/null; then
        print_success "Phase 2 Octopus configuration appears to be deployed"
        return 0
    else
        print_status "Phase 2 Octopus configuration needs to be deployed"
        return 1
    fi
}

# Clean up any existing resources (optional)
cleanup() {
    print_header "CLEANING UP EXISTING RESOURCES"
    print_warning "This will destroy any existing Octopus Deploy resources!"
    read -p "Do you want to clean up existing resources? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd terraform
        print_status "Destroying existing Terraform resources..."
        terraform destroy -auto-approve || print_warning "Some resources may not exist yet"
        
        # Also clean up any orphaned helm releases
        helm uninstall -n octopus-agent-docker-desktop docker-desktop 2>/dev/null || true
        helm uninstall -n kube-system csi-driver-nfs 2>/dev/null || true
        
        # Force delete namespaces if they're stuck
        kubectl delete namespace octopus --force --grace-period=0 2>/dev/null || true
        kubectl delete namespace octopus-agent-docker-desktop --force --grace-period=0 2>/dev/null || true
        
        cd ..
        print_success "Cleanup completed!"
    else
        print_status "Skipping cleanup"
    fi
}

# Phase 1: Deploy Infrastructure
deploy_phase1() {
    print_header "PHASE 1: DEPLOYING INFRASTRUCTURE"
    
    if check_phase1_status; then
        print_status "Phase 1 already deployed, checking if Octopus is ready..."
        if wait_for_octopus_api; then
            print_success "Phase 1 is ready!"
            return 0
        else
            print_warning "Phase 1 exists but Octopus API is not ready, waiting..."
        fi
    fi
    
    cd terraform
    
    print_status "Initializing Terraform..."
    terraform init
    
    # Define Phase 1 targets
    local phase1_targets=(
        "kubernetes_namespace.octopus"
        "kubernetes_service_account.octopus_deploy"
        "kubernetes_cluster_role.octopus_deploy"
        "kubernetes_cluster_role_binding.octopus_deploy"
        "kubernetes_secret.octopus_config"
        "kubernetes_secret.octopus_deploy_token"
        "kubernetes_persistent_volume_claim.kubectl_tools"
        "kubernetes_persistent_volume_claim.octopus_repository"
        "kubernetes_persistent_volume_claim.octopus_artifacts"
        "kubernetes_persistent_volume_claim.octopus_task_logs"
        "kubernetes_persistent_volume_claim.octopus_server_logs"
        "kubernetes_deployment.mssql"
        "kubernetes_service.mssql"
        "kubernetes_manifest.octopus_deployment"
        "kubernetes_service.octopus_web"
        "kubernetes_service.octopus_tentacle"
    )
    
    # Build target arguments
    local target_args=""
    for target in "${phase1_targets[@]}"; do
        target_args="$target_args -target=$target"
    done
    
    print_status "Planning Phase 1 deployment (infrastructure only)..."
    terraform plan $target_args
    
    print_status "Applying Phase 1 deployment (infrastructure only)..."
    terraform apply -auto-approve $target_args
    
    cd ..
    
    print_success "Phase 1 deployment completed!"
    
    # Wait for pods to be ready
    wait_for_pods "octopus" 300
    
    # Wait for Octopus API
    wait_for_octopus_api
    
    print_success "Octopus Deploy is ready!"
    print_status "You can access Octopus at: http://localhost"
    print_status "Username: admin"
    print_status "Password: Password01!"
}

# Function to get API key from user
get_api_key() {
    print_header "API KEY SETUP" >&2
    
    # Check if API key is already configured
    if [ -f "terraform/terraform.tfvars" ] && grep -q "octopus_api_key.*API-" terraform/terraform.tfvars; then
        local existing_key=$(grep "octopus_api_key" terraform/terraform.tfvars | sed -n 's/.*"\(API-[A-Z0-9]*\)".*/\1/p')
        print_status "Found existing API key: ${existing_key:0:10}..." >&2
        read -p "Do you want to use the existing API key? (Y/n): " -n 1 -r
        echo >&2
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "$existing_key"
            return 0
        fi
    fi
    
    print_status "Opening Octopus Deploy in your default browser..." >&2
    if command -v open &> /dev/null; then
        open http://localhost
    elif command -v xdg-open &> /dev/null; then
        xdg-open http://localhost
    else
        print_warning "Could not open browser automatically" >&2
    fi
    
    echo >&2
    print_status "Please follow these steps to create an API key:" >&2
    echo "1. Login to Octopus Deploy with:" >&2
    echo "   Username: admin" >&2
    echo "   Password: Password01!" >&2
    echo "2. Go to your profile (top right) → API Keys" >&2
    echo "3. Click 'New API Key'" >&2
    echo "4. Give it a name like 'Terraform Demo'" >&2
    echo "5. Copy the generated API key" >&2
    echo >&2
    
    while true; do
        read -p "Enter your API key (starts with API-): " api_key
        if [[ $api_key =~ ^API-.+ ]]; then
            # Update terraform.tfvars with the API key
            cd terraform
            if [ -f terraform.tfvars ]; then
                # Update or add octopus_api_key
                if grep -q "octopus_api_key" terraform.tfvars; then
                    sed -i.bak "s/octopus_api_key = \".*\"/octopus_api_key = \"$api_key\"/" terraform.tfvars
                else
                    echo "octopus_api_key = \"$api_key\"" >> terraform.tfvars
                fi
                print_success "Updated terraform.tfvars with API key" >&2
            fi
            cd ..
            break
        else
            print_error "Invalid API key format. It should start with 'API-'" >&2
        fi
    done
    
    echo "$api_key"
}

# Function to generate bearer token
generate_bearer_token() {
    print_header "BEARER TOKEN GENERATION"
    
    local api_key=$1
    
    # Check if bearer token already exists
    if [ -f "terraform/terraform.tfvars" ] && grep -q "octopus_bearer_token.*eyJ" terraform/terraform.tfvars; then
        local existing_token=$(grep "octopus_bearer_token" terraform/terraform.tfvars | sed -n 's/.*"\(eyJ[^"]*\)".*/\1/p')
        if [ -n "$existing_token" ]; then
            print_success "Found existing bearer token: ${existing_token:0:20}..."
            echo "Do you want to use the existing bearer token? (Y/n): "
            read -r use_existing
            if [[ $use_existing =~ ^[Nn] ]]; then
                print_status "Generating new bearer token..."
            else
                print_success "Using existing bearer token"
                return 0
            fi
        fi
    fi
    
    # Generate bearer token using the script
    if [ -f "generate_agent_bearer_token.sh" ]; then
        print_status "Generating JWT bearer token for Kubernetes Agent..."
        if ./generate_agent_bearer_token.sh "$api_key"; then
            print_success "Bearer token generated successfully!"
        else
            print_error "Failed to generate bearer token"
            exit 1
        fi
    else
        print_error "generate_agent_bearer_token.sh script not found!"
        exit 1
    fi
}

# Phase 2: Deploy Octopus Configuration
deploy_phase2() {
    print_header "PHASE 2: DEPLOYING OCTOPUS CONFIGURATION"
    
    local api_key=$1
    local bearer_token=$2
    
    if check_phase2_status; then
        print_status "Phase 2 already deployed, checking agent status..."
        if wait_for_pods "octopus-agent-docker-desktop" 60; then
            print_success "Phase 2 is ready!"
            return 0
        else
            print_warning "Phase 2 exists but agent may not be ready, continuing..."
        fi
    fi
    
    cd terraform
    
    # Update terraform.tfvars with API key and enable resources
    print_status "Updating configuration with API key..."
    
    # Create backup of tfvars if it doesn't exist
    if [ ! -f "terraform.tfvars.bak" ]; then
        cp terraform.tfvars terraform.tfvars.bak
    fi
    
    # Simple and direct replacement using temporary file
    {
        while IFS= read -r line; do
            if [[ $line =~ ^octopus_api_key ]]; then
                echo "octopus_api_key = \"${api_key}\"  # Add your API key here for Phase 2 configuration"
            elif [[ $line =~ ^create_octopus_resources.*false ]]; then
                echo "create_octopus_resources = true"
            else
                echo "$line"
            fi
        done < terraform.tfvars
    } > terraform.tfvars.new && mv terraform.tfvars.new terraform.tfvars
    
    # Reinitialize to ensure Octopus provider is available
    print_status "Reinitializing Terraform with all providers..."
    terraform init
    
    print_status "Planning Phase 2 deployment (Octopus resources)..."
    terraform plan -var="octopus_bearer_token=${bearer_token}"
    
    print_status "Applying Phase 2 deployment (Octopus resources)..."
    terraform apply -auto-approve -var="octopus_bearer_token=${bearer_token}"
    
    cd ..
    
    print_success "Phase 2 deployment completed!"
    
    # Wait for Kubernetes agent to be ready
    wait_for_pods "octopus-agent-docker-desktop" 180
    
    print_success "Kubernetes Agent is ready!"
}

# Show final status
show_final_status() {
    print_header "DEPLOYMENT COMPLETE!"
    
    cd terraform
    
    print_status "Final status:"
    echo
    terraform output 2>/dev/null || print_warning "Could not retrieve Terraform outputs"
    echo
    
    print_success "✅ Phase 1: Infrastructure deployed"
    print_success "✅ Phase 2: Environments and Agent deployed"
    echo
    
    print_status "Kubernetes resources:"
    echo "📦 Octopus namespace:"
    kubectl get all -n octopus 2>/dev/null || print_warning "Could not retrieve octopus namespace resources"
    echo
    echo "🤖 Kubernetes Agent namespace:"
    kubectl get all -n octopus-agent-docker-desktop 2>/dev/null || print_warning "Could not retrieve agent namespace resources"
    echo
    
    print_status "Access Information:"
    echo "🌐 Octopus Deploy: http://localhost"
    echo "👤 Username: admin"
    echo "🔑 Password: Password01!"
    echo
    
    print_status "Demo Complete! You can now:"
    echo "• Create projects in Octopus Deploy"
    echo "• Deploy to Development, Test, and Production environments"
    echo "• Use the Kubernetes Agent for deployments"
    echo "• Demonstrate kubectl persistence (survives pod restarts)"
    
    cd ..
}

# Main execution
main() {
    print_header "OCTOPUS DEPLOY KUBERNETES DEMO"
    print_status "This script will deploy a complete Octopus Deploy environment"
    print_status "using Infrastructure as Code (Terraform)"
    print_status "This script can be run multiple times safely!"
    
    # Ask if user wants to clean up (only if resources exist)
    if kubectl get namespace octopus &> /dev/null || kubectl get namespace octopus-agent-docker-desktop &> /dev/null; then
        echo
        print_status "Existing Octopus resources detected."
        read -p "Do you want to clean up and start fresh? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup
        fi
    fi
    
    # Phase 1
    deploy_phase1
    
    # Get API Key
    api_key=$(get_api_key)
    
    # Generate Bearer Token
    generate_bearer_token "$api_key"
    
    # Extract bearer token from terraform.tfvars
    bearer_token=$(grep "octopus_bearer_token" terraform/terraform.tfvars | sed -n 's/.*"\(eyJ[^"]*\)".*/\1/p')
    if [ -z "$bearer_token" ]; then
        print_error "Failed to extract bearer token from terraform.tfvars"
        exit 1
    fi
    print_success "Bearer token extracted: ${bearer_token:0:20}..."
    
    # Phase 2
    deploy_phase2 "$api_key" "$bearer_token"
    
    # Show final status
    show_final_status
}

# Handle interruption
trap 'print_error "Demo interrupted!"; exit 1' INT

# Run main function
main "$@"
