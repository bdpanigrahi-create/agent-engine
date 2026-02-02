output "id" {
  description = "The unique identifier for the network attachment"
  value       = google_compute_network_attachment.this.id
}

output "name" {
  description = "The name of the network attachment"
  value       = google_compute_network_attachment.this.name
}