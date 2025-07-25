terraform {
  required_version = ">= 1.0"
  
  required_providers {
    octopusdeploy = {
      source  = "OctopusDeployLabs/octopusdeploy"
      version = "~> 0.21"
    }
  }
}
