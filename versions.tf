terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      # Vertex AI Reasoning Engine (google_vertex_ai_reasoning_engine) 
      # requires at least v5.24.0+
      version = ">= 5.24.0"
    }
  }
}