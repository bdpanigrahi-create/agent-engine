# 1. Project Services and Networking
module "core-project-services" {
  source                      = "github.com/terraform-google-modules/terraform-google-project-factory//modules/project_services?ref=v18.2.0"
  project_id                  = "adc-gad-byoc-dp"
  disable_services_on_destroy = false
  activate_apis               = []
}

module "gcp-essential-services" {
  source                      = "github.com/terraform-google-modules/terraform-google-project-factory//modules/project_services?ref=v18.2.0"
  project_id                  = "adc-gad-byoc-dp"
  disable_services_on_destroy = false
  activate_apis               = ["apphub.googleapis.com", "cloudresourcemanager.googleapis.com"]
}

module "primary-network-infrastructure" {
  source                       = "github.com/terraform-google-modules/terraform-google-network?ref=v13.0.0"
  project_id                   = "adc-gad-byoc-dp"
  subnets                      = [
    {
      "purpose"       = "REGIONAL_MANAGED_PROXY",
      "role"          = "ACTIVE",
      "subnet_ip"     = "10.3.0.0/22",
      "subnet_name"   = "swp-proxy-only-subnet-1",
      "subnet_region" = "us-central1"
    },
    {
      "subnet_name"   = "swp-test-subnet-resource-1",
      "subnet_region" = "us-central1",
      "purpose"       = "PRIVATE",
      "role"          = "ACTIVE",
      "subnet_ip"     = "10.2.0.0/22"
    }
  ]
  bgp_best_path_selection_mode = "STANDARD"
  network_name                 = "primary-vpc-network"
  depends_on                   = [module.core-project-services, module.gcp-essential-services]
}

# 2. Secure Web Proxy
module "gateway-security-proxy" {
  source     = "github.com/A0G1/terraform-google-secure-web-proxy?ref=v1.0.2"
  project_id = "adc-gad-byoc-dp"
  region     = "us-central1"
  network    = "projects/adc-gad-byoc-dp/global/networks/primary-vpc-network"
  subnetwork = "projects/adc-gad-byoc-dp/regions/us-central1/subnetworks/swp-test-subnet-resource-1"
  rules = {
    allow-google-com = {
      basic_profile   = "ALLOW"
      description     = "allow access to google.com"
      enabled         = true
      priority        = 100
      session_matcher = "host() == 'google.com' || host() == 'www.google.com'"
    }
  }
  gateway_name     = "primary-gateway"
  certificate_urls = []
  policy = {
    description = "security policy for gateway proxy"
    name        = "gateway-security-policy"
  }
  depends_on = [module.core-project-services, module.gcp-essential-services, module.primary-network-infrastructure]
}

# 3. Network Attachment Module
module "psc-network-attachment" {
  source     = "./modules/network-attachment"
  project_id = "adc-gad-byoc-dp"
  name       = "psc-endpoint-attachment"
  region     = "us-central1"
  
  # Fetching the private subnet from the VPC module
  subnetwork_self_links = module.primary-network-infrastructure.subnets_self_links[1]
}

# 4. Vertex AI Reasoning Engine Module
module "ai-reasoning-engine" {
  source       = "./modules/agent_engine"
  project_id   = "adc-gad-byoc-dp"
  region       = "us-central1"
  display_name = "AI Reasoning Engine Instance"

  # Networking linking
  network_attachment_id = module.psc-network-attachment.id

  # GCS URIs (Constructed using your existing naming convention)
  requirements_gcs_uri  = "gs://aayush-agentic-bucket-2/requirements.txt"
  pickle_object_gcs_uri = "gs://aayush-agentic-bucket-2/agent.pkl"

  # Framework & Versioning
  python_version  = "3.13"
  agent_framework = "google-adk"

  # Proxy environment variables
  env_vars = {
    PROXY_IP = module.gateway-security-proxy.proxy_ip_address
  }

  depends_on = [
    module.primary-network-infrastructure,
    module.gateway-security-proxy
  ]
}