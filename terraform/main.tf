# Create environments
resource "octopusdeploy_environment" "environments" {
  for_each = toset(var.environment_names)
  
  name                         = each.value
  description                  = "Environment for ${each.value}"
  allow_dynamic_infrastructure = true
  use_guided_failure           = false
}

# Create a project group
resource "octopusdeploy_project_group" "main" {
  name        = var.project_group_name
  description = "Main project group managed by Terraform"
}

# Example lifecycle
resource "octopusdeploy_lifecycle" "main" {
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
      optional_deployment_targets           = [octopusdeploy_environment.environments[phase.value].id]
      is_optional_phase                     = false
      minimum_environments_before_promotion = 0
    }
  }
}
