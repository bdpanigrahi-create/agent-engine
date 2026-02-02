variable "project_id" { 
  type        = string
  description = "The GCP Project ID where resources will be deployed"
}

variable "region" { 
  type    = string 
  default = "us-central1" 
}

variable "display_name" { 
  type = string 
}

# GCS Paths
variable "requirements_gcs_uri" { 
  type        = string
  description = "The GCS URI for requirements.txt"
}

variable "pickle_object_gcs_uri" { 
  type        = string
  description = "The GCS URI for agent.pkl"
}

# Framework Settings
variable "agent_framework" { 
  type    = string 
  default = "google-adk" 
}

variable "python_version" { 
  type    = string 
  default = "3.11" 
}

# Networking
variable "subnetwork_self_link" { 
  type        = string
  description = "The self_link of the subnet for the network attachment"
}

variable "env_vars" {
  type    = map(string)
  default = {}
}