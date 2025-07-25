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

output "port_forward_command" {
  description = "Command to port-forward to the Octopus web interface"
  value       = "kubectl port-forward deployment/octopus-web 8080:80 -n ${var.namespace}"
}

output "environments" {
  description = "Created environments"
  value       = var.create_octopus_resources && var.octopus_api_key != "" ? { for env in octopusdeploy_environment.environments : env.name => env.id } : {}
}

output "project_group_id" {
  description = "The ID of the created project group"
  value       = var.create_octopus_resources && var.octopus_api_key != "" && length(octopusdeploy_project_group.main) > 0 ? octopusdeploy_project_group.main[0].id : null
}

output "kubernetes_deployment_target_id" {
  description = "The ID of the created Kubernetes deployment target"
  value       = var.create_octopus_resources && var.octopus_api_key != "" && length(octopusdeploy_kubernetes_cluster_deployment_target.docker_desktop) > 0 ? octopusdeploy_kubernetes_cluster_deployment_target.docker_desktop[0].id : null
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
