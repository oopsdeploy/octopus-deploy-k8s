provider "octopusdeploy" {
  address  = var.octopus_server_url
  api_key  = var.octopus_api_key
  space_id = var.octopus_space_id
}
