output "reasoning_engine_id" {
  description = "The full resource name (ID) of the deployed Reasoning Engine"
  value       = google_vertex_ai_reasoning_engine.this.id
}

output "reasoning_engine_name" {
  description = "The short name of the Reasoning Engine"
  value       = google_vertex_ai_reasoning_engine.this.name
}

output "network_attachment_id" {
  description = "The ID of the Network Attachment created for PSC"
  value       = google_compute_network_attachment.this.id
}

output "service_agent_identity" {
  description = "The Vertex AI Service Agent that was granted network permissions"
  value       = "service-${data.google_project.project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}