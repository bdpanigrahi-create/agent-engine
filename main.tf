# Fetch project information to get the project number dynamically
data "google_project" "project" {
  project_id = var.project_id
}

# Network Attachment for Private Service Connect (PSC)
resource "google_compute_network_attachment" "this" {
  name                  = "${var.display_name}-nw-attachment"
  region                = var.region
  project               = var.project_id
  connection_preference = "ACCEPT_MANUAL"
  subnetworks           = [var.subnetwork_self_link]
}

# Grant Vertex AI Service Agent permission to use the Network Attachment
# Constructed using the project number retrieved from the data source
resource "google_project_iam_member" "vertex_ai_psc_user" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}

# The Reasoning Engine Deployment
resource "google_vertex_ai_reasoning_engine" "this" {
  display_name = var.display_name
  project      = var.project_id
  region       = var.region

  spec {
    agent_framework = var.agent_framework
    package_spec {
      python_version        = var.python_version
      pickle_object_gcs_uri = var.pickle_object_gcs_uri
      requirements_gcs_uri  = var.requirements_gcs_uri
    }
    deployment_spec {
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }
      psc_interface_config {
        network_attachment = google_compute_network_attachment.this.id
      }
    }
  }

  depends_on = [
    google_project_iam_member.vertex_ai_psc_user
  ]
}