provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

resource "google_container_cluster" "primary" {
  name     = "prod-cluster"
  location = var.location

  networking_mode = "VPC_NATIVE"

  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    machine_type = "e2-medium"
    disk_type    = "pd-standard"  # Use standard persistent disk
    disk_size_gb = 50             # Reduce the size to fit within quota
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }


  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}


resource "google_container_node_pool" "primary_nodes" {
  name       = "prod-cluster-node-pool"
  cluster    = google_container_cluster.primary.name
  location   = var.location
  node_count = 1

   node_config {
      machine_type = "e2-medium"
      disk_type    = "pd-standard"
      disk_size_gb = 50
  
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
  
      tags = ["no-external-ip"]
  
      metadata = {
        disable-legacy-endpoints = "true"
      }
    }
}
resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = google_compute_network.vpc.name
  region  = "us-central1"
}

resource "google_compute_router_nat" "nat_config" {
  name                               = "nat-config"
  router                             = google_compute_router.nat_router.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

data "google_client_config" "default" {}


provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)

}

resource "kubernetes_namespace" "example" {
  metadata {
    name = var.namespace
  }
}
