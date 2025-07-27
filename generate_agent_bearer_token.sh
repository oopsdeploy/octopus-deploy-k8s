#!/bin/bash

# Script to generate a proper bearer token (JWT) for Kubernetes Agent registration
# Uses the /users/access-token endpoint to create a JWT bearer token

set -e

# Check if API key is provided as argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <API_KEY>"
    echo "Example: $0 API-ABCD1234..."
    exit 1
fi

# Configuration
OCTOPUS_URL="http://localhost"
API_KEY="$1"

echo "🔑 Generating Kubernetes Agent bearer token (JWT)..."

# Use the correct endpoint to generate an access token (JWT)
echo "🎫 Creating JWT bearer token..."
BEARER_TOKEN_RESPONSE=$(curl -s -X POST \
  "${OCTOPUS_URL}/api/users/access-token" \
  -H "X-Octopus-ApiKey: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "Purpose": "Kubernetes Agent Bearer Token",
    "ExpiresAt": null
  }')

# Extract the bearer token from response
BEARER_TOKEN=$(echo "$BEARER_TOKEN_RESPONSE" | grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4)

# If that doesn't work, try alternative parsing
if [ -z "$BEARER_TOKEN" ]; then
    BEARER_TOKEN=$(echo "$BEARER_TOKEN_RESPONSE" | sed -n 's/.*"AccessToken": *"\([^"]*\)".*/\1/p')
fi

if [ -n "$BEARER_TOKEN" ]; then
    echo "✅ Generated bearer token successfully!"
    echo ""
    echo "Bearer Token (JWT): ${BEARER_TOKEN:0:50}..."
    echo ""
    echo "Update your terraform.tfvars:"
    echo "octopus_bearer_token = \"$BEARER_TOKEN\""
    
    # Auto-update terraform.tfvars
    cd terraform 2>/dev/null || true
    if [ -f terraform.tfvars ]; then
        sed -i.bak "s/octopus_bearer_token = \".*\"/octopus_bearer_token = \"$BEARER_TOKEN\"/" terraform.tfvars
        echo "✅ Updated terraform.tfvars automatically"
    fi
    
    echo ""
    echo "🚀 Ready to deploy! Run: ./demo.sh"
else
    echo "❌ Failed to generate bearer token"
    echo "Response: $BEARER_TOKEN_RESPONSE"
    
    # Check if it's an error response
    if echo "$BEARER_TOKEN_RESPONSE" | grep -q "ErrorMessage"; then
        echo ""
        echo "Error details:"
        echo "$BEARER_TOKEN_RESPONSE" | grep -o '"ErrorMessage":"[^"]*"' | cut -d'"' -f4
    fi
    exit 1
fi \

