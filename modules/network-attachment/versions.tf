terraform {
  # Minimum version of Terraform CLI
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      # This resource is stable in 5.x and 6.x series
      version = ">= 5.0.0"
    }
  }
}