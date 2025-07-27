# How to Generate a Bearer Token for Kubernetes Agent

## Method 1: Automated Script (Recommended)

The `demo.sh` script now handles bearer token generation automatically! Simply run:

```bash
./demo.sh
```

The script will:
1. **Prompt for API Key**: Guide you through creating an API key in Octopus UI
2. **Auto-Update terraform.tfvars**: Automatically saves your API key
3. **Generate JWT Bearer Token**: Calls `generate_agent_bearer_token.sh` with your API key
4. **Auto-Update terraform.tfvars**: Automatically saves the bearer token
5. **Deploy Everything**: Proceeds with Phase 2 deployment

### Manual Bearer Token Generation

If you need to generate a bearer token manually:

```bash
# Generate with your API key
./generate_agent_bearer_token.sh "API-YOUR-KEY-HERE"
```

This script:
- ✅ Accepts API key as parameter (no hardcoded values)
- 🎫 Calls Octopus `/users/access-token` endpoint
- 🔄 Automatically updates `terraform.tfvars`
- ✨ Provides clear usage instructions

## Method 2: Through Octopus UI (Manual)

1. **Open Octopus Deploy**: Go to http://localhost
2. **Login**: Use admin / Password01!
3. **Navigate**: Infrastructure → Deployment Targets
4. **Add Target**: Click "Add Deployment Target"
5. **Select Type**: Choose "Kubernetes Agent"
6. **Configure**: 
   - Name: docker-desktop (or any name)
   - Environments: Select Development, Test, Production
   - Tags: k8s
7. **Generate Commands**: The UI will show Helm installation commands
8. **Copy Token**: Look for the `--set agent.bearerToken="..."` line
9. **Extract Token**: Copy the long string that starts with `eyJ`

Example from the generated command:
```bash
--set agent.bearerToken="eyJhbGciOiJQUzI1NiIsImtpZCI6Im96..."
```

## Method 3: Using Existing API Key as Bearer Token

Sometimes the API key itself can work as a bearer token. You can try using your current API key:

```bash
# In terraform.tfvars, set:
octopus_bearer_token = "API-KY4QDZIJLFXDJVNDWIPQQGA6TQUMYTU"
```

## Method 4: Create New API Key

1. **Go to**: Configuration → Users → admin → API Keys
2. **Create**: New API Key with purpose "Kubernetes Agent"  
3. **Copy**: The generated API key
4. **Use**: As bearer token in terraform.tfvars

## ⚠️ Important Notes

- **No Manual Updates Needed**: The `demo.sh` script handles all terraform.tfvars updates automatically
- **Parameter Passing**: The `generate_agent_bearer_token.sh` script now accepts API key as parameter
- **JWT Tokens**: Generated tokens are proper JWTs from `/users/access-token` endpoint
- **Secure**: No hardcoded credentials in any scripts

## Update terraform.tfvars (Manual Method Only)

⚠️ **Only needed if NOT using `demo.sh`**

Once you have a bearer token, update your configuration:

```bash
cd terraform
# Edit terraform.tfvars and set:
octopus_bearer_token = "YOUR_BEARER_TOKEN_HERE"
```

## Quick Start (Recommended)

```bash
# Just run the demo - it handles everything!
./demo.sh
```
