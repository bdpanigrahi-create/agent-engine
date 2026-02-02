resource "google_compute_network_attachment" "this" {
  name                  = var.name
  project               = var.project_id
  region                = var.region
  description           = var.description
  connection_preference = var.connection_preference

  subnetworks = var.subnetwork_self_links
}