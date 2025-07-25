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

# Create Kubernetes deployment target for the current cluster
resource "octopusdeploy_kubernetes_cluster_deployment_target" "docker_desktop" {
  count = var.create_octopus_resources && var.octopus_api_key != "" ? 1 : 0
  
  name         = "docker-desktop"
  environments = [for env in octopusdeploy_environment.environments : env.id]
  roles        = ["k8s"]
  
  cluster_url                = var.kubernetes_cluster_url
  skip_tls_verification      = var.kubernetes_skip_tls_verification
  default_worker_pool_id     = var.kubernetes_worker_pool_id
  
  # Use the service account token from the octopus namespace
  authentication {
    account_id = octopusdeploy_token_account.kubernetes_service_account[0].id
  }

  depends_on = [octopusdeploy_environment.environments]
}

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
