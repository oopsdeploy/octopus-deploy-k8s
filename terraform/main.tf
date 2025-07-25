# Octopus Deploy on Kubernetes - Terraform Configuration
#
# This configuration is split into two phases:
#
# Phase 1 (phase1.tf): Infrastructure deployment (Kubernetes namespace, Helm charts)
# - Does not require Octopus API key
# - Deploys Octopus Server and SQL Server containers
# 
# Phase 2 (phase2.tf): Octopus configuration (environments, project groups, lifecycles)
# - Requires Octopus API key and running server
# - Creates Octopus Deploy resources
#
# Usage:
# 1. Run Phase 1: terraform apply -target=module.phase1
# 2. Get API key from Octopus web interface
# 3. Update terraform.tfvars with API key and set create_octopus_resources = true
# 4. Run Phase 2: terraform apply
