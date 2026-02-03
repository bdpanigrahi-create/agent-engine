variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "name" {
  type        = string
  description = "Name of the network attachment"
}

variable "description" {
  type    = string
  default = "Network attachment managed by Terraform"
}

variable "connection_preference" {
  type        = string
  default     = "ACCEPT_MANUAL"
  description = "The connection preference of the network attachment. Likely ACCEPT_MANUAL or ACCEPT_AUTOMATIC"
}

variable "subnetwork_self_link" {
  type        = string
  description = "subnetwork self link"
}