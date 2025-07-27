#!/bin/bash

# Helper script to install kubectl in the Octopus Deploy container
# This is needed for Kubernetes API deployment targets to work properly

set -e

echo "🔧 Installing kubectl in Octopus Deploy container..."

# Check if octopus pod is running
if ! kubectl get pods -n octopus -l app=octopus --field-selector=status.phase=Running | grep -q octopus; then
    echo "❌ Error: No running octopus pod found in octopus namespace"
    echo "   Make sure Octopus Deploy is running: kubectl get pods -n octopus -l app=octopus"
    exit 1
fi

# Get the pod name
POD_NAME=$(kubectl get pods -n octopus -l app=octopus --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "❌ Error: Could not get octopus pod name"
    exit 1
fi

echo "🔍 Found Octopus pod: $POD_NAME"

# Check if kubectl is already installed
echo "🔍 Checking if kubectl is already installed..."
if kubectl exec -n octopus "$POD_NAME" -- kubectl version --client >/dev/null 2>&1; then
    echo "✅ kubectl is already installed and working!"
    kubectl exec -n octopus "$POD_NAME" -- kubectl version --client
    echo ""
    echo "🎯 Your Kubernetes deployment target health check should pass."
    echo "   You can verify this in the Octopus Deploy web interface at http://localhost"
    exit 0
fi

# Check if kubectl exists in the shared volume
echo "🔍 Checking if kubectl exists in shared volume..."
if kubectl exec -n octopus "$POD_NAME" -- test -f /shared/bin/kubectl; then
    echo "✅ kubectl found in shared volume! It was installed by the init container."
    kubectl exec -n octopus "$POD_NAME" -- /shared/bin/kubectl version --client
    echo ""
    echo "🎯 Your Kubernetes deployment target health check should pass."
    echo "   You can verify this in the Octopus Deploy web interface at http://localhost"
    echo ""
    echo "✨ GREAT NEWS: kubectl will persist across pod restarts thanks to the init container!"
    exit 0
fi

# Install kubectl (fallback - should not be needed with init container)
echo "📥 Init container didn't install kubectl. Installing manually..."
kubectl exec -n octopus "$POD_NAME" -- bash -c "
    curl -LO https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl && 
    chmod +x kubectl && 
    mv kubectl /usr/local/bin/ && 
    kubectl version --client
"

echo "✅ kubectl installation completed!"
echo ""
echo "🎯 Your Kubernetes deployment target health check should now pass."
echo "   You can verify this in the Octopus Deploy web interface at http://localhost"
echo ""
echo "⚠️  IMPORTANT: kubectl will be lost if the pod restarts!"
echo "   Run this script again after pod restarts: ./kubectl-install.sh"
echo ""
echo "💡 To check if the pod has restarted, monitor: kubectl get pods -n octopus -l app=octopus -w"
