output "octopus_namespace" {
  description = "The Kubernetes namespace where Octopus Deploy is installed"
  value       = kubernetes_namespace.octopus.metadata[0].name
}

output "octopus_master_key" {
  description = "The generated master key for Octopus Deploy (base64 encoded)"
  value       = base64encode(random_password.octopus_master_key.result)
  sensitive   = true
}

output "octopus_server_url" {
  description = "The URL of the Octopus Deploy server"
  value       = var.octopus_server_url
}

output "octopus_admin_credentials" {
  description = "Admin credentials for Octopus Deploy"
  value = {
    username = var.octopus_admin_username
    password = var.octopus_admin_password
  }
  sensitive = true
}

output "access_instructions" {
  description = "How to access Octopus Deploy"
  value       = "Access Octopus Deploy at ${var.octopus_server_url} with username '${var.octopus_admin_username}' and the configured password"
}

output "environments" {
  description = "Created environments"
  value       = var.create_octopus_resources && var.octopus_api_key != "" ? { for env in octopusdeploy_environment.environments : env.name => env.id } : {}
}

output "project_group_id" {
  description = "The ID of the created project group"
  value       = var.create_octopus_resources && var.octopus_api_key != "" && length(octopusdeploy_project_group.main) > 0 ? octopusdeploy_project_group.main[0].id : null
}

output "kubernetes_agent_release_status" {
  description = "Status of the Kubernetes Agent Helm release"
  value       = var.create_octopus_resources && var.octopus_api_key != "" && var.octopus_bearer_token != "" && length(helm_release.kubernetes_agent) > 0 ? helm_release.kubernetes_agent[0].status : null
}

output "kubernetes_agent_namespace" {
  description = "Namespace where the Kubernetes Agent is deployed"
  value       = var.create_octopus_resources && var.octopus_api_key != "" && var.octopus_bearer_token != "" ? "octopus-agent-${var.kubernetes_agent_name}" : null
}

output "service_account_token_account_id" {
  description = "The ID of the service account token account"
  value       = var.create_octopus_resources && var.octopus_api_key != "" && length(octopusdeploy_token_account.kubernetes_service_account) > 0 ? octopusdeploy_token_account.kubernetes_service_account[0].id : null
}

output "kubernetes_service_account_name" {
  description = "The name of the created Kubernetes service account"
  value       = kubernetes_service_account.octopus_deploy.metadata[0].name
}

output "kubernetes_cluster_role_name" {
  description = "The name of the created cluster role"
  value       = kubernetes_cluster_role.octopus_deploy.metadata[0].name
}

output "helm_release_status" {
  description = "Status of the Octopus Helm release"
  value       = helm_release.octopus_server.status
}

output "kubectl_get_pods_command" {
  description = "Command to check Octopus Deploy pods"
  value       = "kubectl get pods -n ${var.namespace}"
}
