variable "octopus_server_url" {
  description = "The URL of your Octopus Deploy server"
  type        = string
  default     = "http://localhost:8080"
}

variable "octopus_api_key" {
  description = "API key for Octopus Deploy authentication"
  type        = string
  sensitive   = true
}

variable "octopus_space_id" {
  description = "The ID of the Octopus Deploy space to manage"
  type        = string
  default     = "Spaces-1"  # Default space ID
}

variable "environment_names" {
  description = "List of environment names to create"
  type        = list(string)
  default     = ["Development", "Test", "Production"]
}

variable "project_group_name" {
  description = "Name of the project group to create"
  type        = string
  default     = "Default Project Group"
}
