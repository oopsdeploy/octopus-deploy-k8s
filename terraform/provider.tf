provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Octopus provider - configured for Phase 2 deployment
provider "octopusdeploy" {
  address  = var.octopus_server_url
  api_key  = var.octopus_api_key
  space_id = var.octopus_space_id
}
