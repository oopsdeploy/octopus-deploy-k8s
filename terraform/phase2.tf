# Phase 2: Octopus Configuration (requires API key and running Octopus server)

# Create environments (only if create_octopus_resources is true and API key is provided)
resource "octopusdeploy_environment" "environments" {
  for_each = var.create_octopus_resources && var.octopus_api_key != "" ? toset(var.environment_names) : toset([])
  
  name                         = each.value
  description                  = "Environment for ${each.value}"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false

  depends_on = [helm_release.octopus_server]
}

# Create a project group (only if create_octopus_resources is true and API key is provided)
resource "octopusdeploy_project_group" "main" {
  count = var.create_octopus_resources && var.octopus_api_key != "" ? 1 : 0
  
  name        = var.project_group_name
  description = "Main project group managed by Terraform"

  depends_on = [helm_release.octopus_server]
}

# Deploy CSI Driver NFS (required for Kubernetes Agent)
resource "helm_release" "csi_driver_nfs" {
  count = var.create_octopus_resources && var.octopus_api_key != "" ? 1 : 0
  
  name       = "csi-driver-nfs"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  namespace  = "kube-system"
  version    = "v4.*.*"
  
  atomic = true
  
  depends_on = [octopusdeploy_environment.environments]
}

# Deploy Kubernetes Agent
resource "helm_release" "kubernetes_agent" {
  count = var.create_octopus_resources && var.octopus_api_key != "" ? 1 : 0
  
  name             = var.kubernetes_agent_name
  repository       = "oci://registry-1.docker.io/octopusdeploy"
  chart            = "kubernetes-agent"
  namespace        = "octopus-agent-${var.kubernetes_agent_name}"
  create_namespace = true
  version          = "2.*.*"
  
  atomic = true
  
  values = [
    yamlencode({
      agent = {
        acceptEula = "Y"
        space = "Default"  # Use space name, not ID
        serverUrl = var.octopus_server_internal_url
        serverCommsAddresses = ["tcp://${replace(var.octopus_server_internal_url, "http://", "")}:10943"]
        # Use API key instead of bearer token for authentication
        serverApiKey = var.octopus_api_key
        name = var.kubernetes_agent_name
        deploymentTarget = {
          initial = {
            environments = var.environment_names
            tags = ["k8s"]
          }
          enabled = "true"
        }
      }
    })
  ]
  
  depends_on = [helm_release.csi_driver_nfs, octopusdeploy_environment.environments]
}

# Note: The Kubernetes Agent will automatically create its deployment target in Octopus
# We don't need to create it manually with Terraform since the agent registers itself

# Create a token account for the Kubernetes service account
resource "octopusdeploy_token_account" "kubernetes_service_account" {
  count = var.create_octopus_resources && var.octopus_api_key != "" ? 1 : 0
  
  name        = "docker-desktop-service-account"
  description = "Service account token for docker-desktop Kubernetes cluster"
  token       = data.kubernetes_secret.octopus_deploy_token.data["token"]

  depends_on = [helm_release.octopus_server]
}

# Data source to get the service account token
data "kubernetes_secret" "octopus_deploy_token" {
  metadata {
    name      = kubernetes_secret.octopus_deploy_token.metadata[0].name
    namespace = var.namespace
  }
}

# Create lifecycle (only if create_octopus_resources is true and API key is provided)
resource "octopusdeploy_lifecycle" "main" {
  count = var.create_octopus_resources && var.octopus_api_key != "" ? 1 : 0
  
  name        = "Terraform Managed Lifecycle"
  description = "Lifecycle managed by Terraform"

  release_retention_policy {
    quantity_to_keep    = 30
    should_keep_forever = false
    unit                = "Items"
  }

  tentacle_retention_policy {
    quantity_to_keep    = 30
    should_keep_forever = false
    unit                = "Items"
  }

  dynamic "phase" {
    for_each = var.environment_names
    content {
      name                                  = phase.value
      automatic_deployment_targets          = []
      optional_deployment_targets           = length(octopusdeploy_environment.environments) > 0 ? [octopusdeploy_environment.environments[phase.value].id] : []
      is_optional_phase                     = false
      minimum_environments_before_promotion = 0
    }
  }

  depends_on = [octopusdeploy_environment.environments]
}
