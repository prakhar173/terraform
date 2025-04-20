variable "credentials_file" {
  description = "Path to GCP SA key file"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  default     = "us-central1"
  description = "GCP region"
}

variable "cluster_name" {
  default     = "prod-cluster"
  description = "GKE cluster name"
}

variable "namespace" {
  default     = "my-namespace"
  description = "Kubernetes namespace name"
}

variable "location" {
  description = "The location (region or zone) for GKE cluster"
  type        = string
  default     = "us-central1"
}
