# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Data

# data "terraform_remote_state" "gke" {
#   backend = "local"

#   config = {
#     path = "../terraform/terraform.tfstate"
#   }
# }

# data "google_client_config" "default" {}

# data "google_container_cluster" "my_cluster" {
#   name     = data.terraform_remote_state.gke.outputs.kubernetes_cluster_name
#   location = data.terraform_remote_state.gke.outputs.region
# }



# Definition of local variables
locals {
  base_apis = [
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudprofiler.googleapis.com"
  ]
  memorystore_apis = ["redis.googleapis.com"]
  cluster_name     = google_container_cluster.my_cluster.name
}

# Enable Google Cloud APIs
module "enable_google_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.0"

  project_id                  = var.project_id
  disable_services_on_destroy = false

  # activate_apis is the set of base_apis and the APIs required by user-configured deployment options
  activate_apis = concat(local.base_apis, var.memorystore ? local.memorystore_apis : [])
}

# Create GKE cluster

data "google_container_engine_versions" "gke_version" {
  location = var.region
  version_prefix = "1.27."
}

resource "google_container_cluster" "my_cluster" {
  name     = "${var.name}-gke"
  location = var.region

  # Enabling autopilot for this cluster
  enable_autopilot = true

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  # remove_default_node_pool = true
  # initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  depends_on = [
    module.enable_google_apis
  ]
}

# Separately Managed Node Pool
# resource "google_container_node_pool" "primary_nodes" {
#   name       = google_container_cluster.my_cluster.name
#   location   = var.location
#   cluster    = google_container_cluster.my_cluster.name
  
#   version = data.google_container_engine_versions.gke_version.release_channel_latest_version["STABLE"]
#   node_count = var.gke_num_nodes

#   node_config {
#     oauth_scopes = [
#       "https://www.googleapis.com/auth/logging.write",
#       "https://www.googleapis.com/auth/monitoring",
#     ]

#     labels = {
#       env = var.name
#     }

#     # preemptible  = true
#     machine_type = "n1-standard-1"
#     tags         = ["gke-node", "${var.name}-gke"]
#     metadata = {
#       disable-legacy-endpoints = "true"
#     }
#   }
# }

# resource "google_container_cluster" "my_cluster" {

#   name     = var.name
#   location = var.region

#   # Enabling autopilot for this cluster
#   enable_autopilot = true

#   # Setting an empty ip_allocation_policy to allow autopilot cluster to spin up correctly
#   ip_allocation_policy {
#   }

#   depends_on = [
#     module.enable_google_apis
#   ]
# }

# # Get credentials for cluster
# module "gcloud" {
#   source  = "terraform-google-modules/gcloud/google"
#   version = "~> 3.0"
#   enabled = var.skip_provisioners

#   platform              = "linux"
#   additional_components = ["kubectl", "beta"]

#   create_cmd_entrypoint = "gcloud"
#   # Module does not support explicit dependency
#   # Enforce implicit dependency through use of local variable
#   create_cmd_body = "container clusters get-credentials ${local.cluster_name} --zone=${var.region} --project=${var.gcp_project_id}"

#   module_depends_on = [
#     resource.google_container_cluster.my_cluster
#   ]
# }

# Apply YAML kubernetes-manifest configurations
resource "null_resource" "apply_deployment" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "kubectl apply -k ${var.filepath_manifest} -n ${var.namespace}"
  }

  depends_on = [
    resource.google_container_cluster.my_cluster
    # module.gcloud
  ]
}

# Wait condition for all Pods to be ready before finishing
resource "null_resource" "wait_conditions" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = <<-EOT
    kubectl wait --for=condition=AVAILABLE apiservice/v1beta1.metrics.k8s.io --timeout=300s
    kubectl wait --for=condition=ready pods --all -n ${var.namespace} --timeout=300s
    EOT
  }

  depends_on = [
    resource.null_resource.apply_deployment
  ]
}

resource "null_resource" "apply_prometheus-CRD" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "kubectl apply --server-side -f ${var.filepath_manifest_prometheus-CRD}"
  }

  depends_on = [
    resource.null_resource.wait_conditions
  ]
}

# Wait condition for all Pods to be ready before finishing
resource "null_resource" "wait_conditions-CRD" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = <<-EOT
    kubectl wait \
      --for condition=Established \
      --all CustomResourceDefinition \
      --namespace=monitoring --timeout=300s
    EOT
  }

  depends_on = [
    resource.null_resource.apply_prometheus-CRD
  ]
}

resource "null_resource" "apply_prometheus-stack" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "kubectl apply -f ${var.filepath_manifest_prometheus-stack} -n ${var.namespace-monitoring}"
  }

  depends_on = [
    resource.null_resource.wait_conditions-CRD
  ]
}

resource "null_resource" "apply_loki" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "kubectl apply -k ${var.filepath_manifest_loki} -n ${var.namespace-monitoring}"
  }

  depends_on = [
    resource.null_resource.wait_conditions-CRD
  ]
}
