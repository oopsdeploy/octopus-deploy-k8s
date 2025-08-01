variable "octopus_server_url" {
  description = "The URL of your Octopus Deploy server (external access for Terraform provider)"
  type        = string
  default     = "http://localhost"
}

variable "octopus_server_internal_url" {
  description = "The internal URL of your Octopus Deploy server (for Kubernetes Agent)"
  type        = string
  default     = "http://octopus-web.octopus.svc.cluster.local"
}

variable "octopus_api_key" {
  description = "API key for Octopus Deploy authentication (leave empty for initial deployment)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "octopus_space_id" {
  description = "The ID of the Octopus Deploy space to manage"
  type        = string
  default     = "Spaces-1"
}

variable "environment_names" {
  description = "List of environment names to create"
  type        = list(string)
  default     = ["Development", "Test", "Production"]
}

variable "project_group_name" {
  description = "Name of the project group to create"
  type        = string
  default     = "Terraform Managed Projects"
}

variable "octopus_admin_username" {
  description = "Admin username for Octopus Deploy"
  type        = string
  default     = "admin"
}

variable "octopus_admin_password" {
  description = "Admin password for Octopus Deploy"
  type        = string
  sensitive   = true
  default     = "Password01!"
}

variable "octopus_image_tag" {
  description = "Octopus Deploy Docker image tag"
  type        = string
  default     = "latest"
}

variable "sqlserver_image_tag" {
  description = "SQL Server Docker image tag"
  type        = string
  default     = "2019-latest"
}

variable "namespace" {
  description = "Kubernetes namespace for Octopus Deploy"
  type        = string
  default     = "octopus"
}

variable "kubectl_version" {
  description = "Version of kubectl to install in the Octopus container"
  type        = string
  default     = "v1.28.0"
}

variable "create_octopus_resources" {
  description = "Whether to create Octopus Deploy resources (environments, project groups, etc.)"
  type        = bool
  default     = false
}

# Kubernetes deployment target configuration
variable "kubernetes_cluster_url" {
  description = "The URL of the Kubernetes cluster for deployment target"
  type        = string
  default     = "https://127.0.0.1:6443"
}

variable "kubernetes_skip_tls_verification" {
  description = "Whether to skip TLS verification for the Kubernetes cluster"
  type        = bool
  default     = true
}

variable "kubernetes_worker_pool_id" {
  description = "The worker pool ID for Kubernetes deployments (empty for default)"
  type        = string
  default     = ""
}

variable "kubernetes_agent_name" {
  description = "Name for the Kubernetes Agent"
  type        = string
  default     = "docker-desktop"
}

variable "octopus_bearer_token" {
  description = "Bearer token for Kubernetes Agent authentication (generated from Octopus UI)"
  type        = string
  default     = ""
  sensitive   = true
}
