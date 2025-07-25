output "octopus_server_url" {
  description = "The URL of the Octopus Deploy server"
  value       = var.octopus_server_url
}

output "environments" {
  description = "Created environments"
  value       = { for env in octopusdeploy_environment.environments : env.name => env.id }
}

output "project_group_id" {
  description = "The ID of the created project group"
  value       = octopusdeploy_project_group.main.id
}
