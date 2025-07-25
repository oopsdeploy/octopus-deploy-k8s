provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Octopus provider - uses dummy values when API key is not provided
provider "octopusdeploy" {
  address  = var.octopus_api_key != "" ? var.octopus_server_url : "http://localhost:8080"
  api_key  = var.octopus_api_key != "" ? var.octopus_api_key : "API-DUMMY-KEY-FOR-INIT-ONLY"
  space_id = var.octopus_api_key != "" ? var.octopus_space_id : "Spaces-1"
}
