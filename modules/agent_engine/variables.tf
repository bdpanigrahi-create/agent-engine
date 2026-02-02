variable "project_id" {
  type        = string
  description = "The GCP Project ID where resources will be deployed"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "The GCP region for the deployment"
}

variable "display_name" {
  type        = string
  description = "The display name for the Vertex AI Reasoning Engine"
}

# Artifacts
variable "requirements_gcs_uri" {
  type        = string
  description = "The full GCS URI for the requirements.txt file (e.g., gs://bucket/reqs.txt)"
}

variable "pickle_object_gcs_uri" {
  type        = string
  description = "The full GCS URI for the agent.pkl file (e.g., gs://bucket/agent.pkl)"
}

# Framework Settings
variable "agent_framework" {
  type        = string
  default     = "google-adk"
  description = "The agent framework being used"
}

variable "python_version" {
  type    = string
  default = "3.11"
}

# External Networking
variable "network_attachment_id" {
  type        = string
  description = "The self_link or ID of the existing Network Attachment for PSC"
}

variable "env_vars" {
  type        = map(string)
  default     = {}
  description = "A map of environment variables to be passed to the agent"
}