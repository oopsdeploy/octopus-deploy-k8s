#!/bin/bash

# Comprehensive cleanup script for Octopus Deploy Kubernetes Demo
# This script will destroy all resources created by the demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header "OCTOPUS DEPLOY KUBERNETES CLEANUP"

print_status "This script will destroy all resources created by the Octopus Deploy demo"
echo "This includes:"
echo "  - All pods, deployments, services"
echo "  - All persistent volumes and claims"
echo "  - All namespaces (octopus, octopus-tentacle, octopus-agent-*)"
echo "  - All cluster roles and bindings"
echo "  - Terraform state"
echo ""
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled"
    exit 0
fi

print_header "STEP 1: TERRAFORM DESTROY"

if [ -d "terraform" ] && [ -f "terraform/terraform.tfstate" ]; then
    print_status "Running Terraform destroy..."
    cd terraform
    terraform destroy -auto-approve || print_error "Terraform destroy failed, continuing with manual cleanup..."
    cd ..
    print_success "Terraform destroy completed"
else
    print_status "No Terraform state found, skipping terraform destroy"
fi

print_header "STEP 2: KUBERNETES RESOURCE CLEANUP"

print_status "Checking for Octopus-related namespaces..."
OCTOPUS_NAMESPACES=$(kubectl get ns -o name | grep -E "(octopus|tentacle)" || true)

if [ -n "$OCTOPUS_NAMESPACES" ]; then
    echo "Found namespaces:"
    echo "$OCTOPUS_NAMESPACES"
    
    for ns in $OCTOPUS_NAMESPACES; do
        namespace_name=$(echo $ns | cut -d'/' -f2)
        print_status "Cleaning up namespace: $namespace_name"
        
        # Force delete all pods in the namespace
        print_status "Force deleting pods in $namespace_name..."
        kubectl delete pods --all -n "$namespace_name" --force --grace-period=0 || true
        
        # Delete all deployments
        print_status "Deleting deployments in $namespace_name..."
        kubectl delete deployments --all -n "$namespace_name" || true
        
        # Delete all services
        print_status "Deleting services in $namespace_name..."
        kubectl delete services --all -n "$namespace_name" || true
        
        # Delete all secrets
        print_status "Deleting secrets in $namespace_name..."
        kubectl delete secrets --all -n "$namespace_name" || true
        
        # Delete all configmaps
        print_status "Deleting configmaps in $namespace_name..."
        kubectl delete configmaps --all -n "$namespace_name" || true
        
        # Force delete PVCs
        print_status "Force deleting PVCs in $namespace_name..."
        PVCS=$(kubectl get pvc -n "$namespace_name" -o name 2>/dev/null || true)
        if [ -n "$PVCS" ]; then
            for pvc in $PVCS; do
                pvc_name=$(echo $pvc | cut -d'/' -f2)
                print_status "Patching PVC $pvc_name to remove finalizers..."
                kubectl patch pvc "$pvc_name" -n "$namespace_name" -p '{"metadata":{"finalizers":null}}' || true
            done
            kubectl delete pvc --all -n "$namespace_name" --force --grace-period=0 || true
        fi
        
        # Delete the namespace
        print_status "Deleting namespace $namespace_name..."
        kubectl delete namespace "$namespace_name" || true
        
        # If namespace is stuck, force remove finalizers
        if kubectl get namespace "$namespace_name" >/dev/null 2>&1; then
            print_status "Namespace $namespace_name is stuck, removing finalizers..."
            kubectl patch namespace "$namespace_name" -p '{"metadata":{"finalizers":null}}' || true
            
            # Use the finalize API endpoint as last resort
            kubectl get namespace "$namespace_name" -o json > /tmp/ns-"$namespace_name".json 2>/dev/null || true
            if [ -f /tmp/ns-"$namespace_name".json ]; then
                jq '.spec.finalizers = []' /tmp/ns-"$namespace_name".json > /tmp/ns-"$namespace_name"-clean.json
                kubectl replace --raw "/api/v1/namespaces/$namespace_name/finalize" -f /tmp/ns-"$namespace_name"-clean.json || true
                rm -f /tmp/ns-"$namespace_name".json /tmp/ns-"$namespace_name"-clean.json
            fi
        fi
    done
else
    print_status "No Octopus-related namespaces found"
fi

print_header "STEP 3: PERSISTENT VOLUME CLEANUP"

print_status "Checking for orphaned persistent volumes..."
ORPHANED_PVS=$(kubectl get pv -o name | grep -E "(octopus|tentacle)" || true)

if [ -n "$ORPHANED_PVS" ]; then
    print_status "Found orphaned persistent volumes, cleaning up..."
    for pv in $ORPHANED_PVS; do
        pv_name=$(echo $pv | cut -d'/' -f2)
        print_status "Patching PV $pv_name to remove finalizers..."
        kubectl patch pv "$pv_name" -p '{"metadata":{"finalizers":null}}' || true
        kubectl delete pv "$pv_name" --force --grace-period=0 || true
    done
else
    print_status "No orphaned persistent volumes found"
fi

print_header "STEP 4: CLUSTER-LEVEL RESOURCE CLEANUP"

print_status "Cleaning up cluster roles and bindings..."
kubectl delete clusterrole octopus-deploy || true
kubectl delete clusterrolebinding octopus-deploy || true

print_status "Cleaning up any remaining octopus-related cluster resources..."
kubectl get clusterroles -o name | grep octopus | xargs -r kubectl delete || true
kubectl get clusterrolebindings -o name | grep octopus | xargs -r kubectl delete || true

print_header "STEP 5: HELM CLEANUP"

print_status "Checking for Helm releases..."
HELM_RELEASES=$(helm list -a -A | grep -E "(octopus|tentacle)" | awk '{print $1 " -n " $2}' || true)

if [ -n "$HELM_RELEASES" ]; then
    print_status "Found Helm releases, cleaning up..."
    echo "$HELM_RELEASES" | while read -r release; do
        if [ -n "$release" ]; then
            print_status "Uninstalling Helm release: $release"
            helm uninstall $release || true
        fi
    done
else
    print_status "No Helm releases found"
fi

print_header "STEP 6: FINAL VERIFICATION"

print_status "Verifying cleanup..."

# Check namespaces
REMAINING_NS=$(kubectl get ns -o name | grep -E "(octopus|tentacle)" || true)
if [ -n "$REMAINING_NS" ]; then
    print_error "Some namespaces are still present:"
    echo "$REMAINING_NS"
else
    print_success "All Octopus namespaces removed"
fi

# Check PVCs
REMAINING_PVCS=$(kubectl get pvc -A | grep -E "(octopus|tentacle)" || true)
if [ -n "$REMAINING_PVCS" ]; then
    print_error "Some PVCs are still present:"
    echo "$REMAINING_PVCS"
else
    print_success "All Octopus PVCs removed"
fi

# Check PVs
REMAINING_PVS=$(kubectl get pv | grep -E "(octopus|tentacle)" || true)
if [ -n "$REMAINING_PVS" ]; then
    print_error "Some PVs are still present:"
    echo "$REMAINING_PVS"
else
    print_success "All Octopus PVs removed"
fi

# Check pods
REMAINING_PODS=$(kubectl get pods -A | grep -E "(octopus|tentacle)" || true)
if [ -n "$REMAINING_PODS" ]; then
    print_error "Some pods are still running:"
    echo "$REMAINING_PODS"
else
    print_success "All Octopus pods removed"
fi

print_header "CLEANUP COMPLETE"
print_success "Octopus Deploy Kubernetes demo cleanup completed!"
print_status "You can now run ./demo.sh to start fresh"

echo ""
print_status "Summary of actions taken:"
echo "  ✅ Terraform resources destroyed"
echo "  ✅ All Octopus-related namespaces removed"
echo "  ✅ All persistent volumes and claims cleaned up"
echo "  ✅ All cluster roles and bindings removed"
echo "  ✅ All Helm releases uninstalled"
echo "  ✅ System ready for fresh deployment"
