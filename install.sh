#!/bin/bash

set -e

echo "🚀 Starting Octopus Deploy installation..."

# Step 1: Add Helm repo
helm repo add octopus https://octopus-helm-charts.s3.amazonaws.com
helm repo update

# Step 2: Create namespace
kubectl create namespace octopus || echo "Namespace already exists"

# Step 3: Generate master key
MASTER_KEY=$(openssl rand -base64 32)

# Step 4: Create Octopus values.yaml
cat <<EOF > octopus-values.yaml
octopus:
  image: octopusdeploy/octopusdeploy:latest
  username: admin
  password: Password01!
  acceptEula: "Y"
  masterKey: "$MASTER_KEY"

mssql-linux:
  acceptEula:
    value: "Y"
  image:
    repository: mcr.microsoft.com/mssql/server
    tag: 2019-latest
EOF

# Step 5: Install Octopus Server
helm upgrade --install octopus octopus/octopusdeploy \
  --namespace octopus \
  -f octopus-values.yaml

echo "🎉 Octopus Deploy installed."

echo "⏳ Waiting for Octopus server to be ready..."
kubectl rollout status deployment octopus-web -n octopus

echo "🌐 Port-forwarding Octopus server to http://localhost:8080"
kubectl port-forward deployment/octopus-web 8080:80 -n octopus &
sleep 5

# Step 6: Prompt for Octopus API Key
read -p "🔑 Enter your Octopus API Key (for Tentacle registration): " API_KEY

# Step 7: Create Tentacle values.yaml
cat <<EOF > tentacle-values.yaml
tentacle:
  serverUrl: http://octopus-web.octopus.svc.cluster.local
  apiKey: $API_KEY
  environment: Dev
  role: worker
  acceptTentacleEula: Y
EOF

# Step 8: Install Tentacle
helm upgrade --install mytentacle octopus/linux-tentacle \
  --namespace octopus \
  -f tentacle-values.yaml

echo "✅ Tentacle deployed. Check Octopus UI for the new target."
