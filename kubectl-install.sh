#!/bin/bash

# Helper script to install kubectl in the Octopus Deploy container
# This is needed for Kubernetes API deployment targets to work properly

set -e

echo "🔧 Installing kubectl in Octopus Deploy container..."

# Check if octopus pod is running
if ! kubectl get pod octopus-0 -n octopus >/dev/null 2>&1; then
    echo "❌ Error: octopus-0 pod not found in octopus namespace"
    echo "   Make sure Octopus Deploy is running: kubectl get pods -n octopus"
    exit 1
fi

# Check if pod is ready
if ! kubectl get pod octopus-0 -n octopus -o jsonpath='{.status.phase}' | grep -q "Running"; then
    echo "❌ Error: octopus-0 pod is not running"
    echo "   Current status: $(kubectl get pod octopus-0 -n octopus -o jsonpath='{.status.phase}')"
    exit 1
fi

# Install kubectl
echo "📥 Downloading and installing kubectl v1.28.0..."
kubectl exec -n octopus octopus-0 -- bash -c "
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
echo "💡 Note: You may need to run this script again if the octopus-0 pod restarts."
