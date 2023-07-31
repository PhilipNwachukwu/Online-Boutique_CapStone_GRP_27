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

variable "project_id" {
  type        = string
  description = "The GCP project ID to apply this config to"
}

variable "name" {
  type        = string
  description = "Name given to the new GKE cluster"
  default     = "online-boutique"
}

variable "region" {
  type        = string
  description = "Region of the new GKE cluster"
  default = "europe-west2"
}

variable "location" {
  type        = string
  description = "Location of the new GKE cluster"
  default = "europe-west2-a"
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 2
  description = "number of gke nodes"
}

variable "namespace" {
  type        = string
  description = "Kubernetes Namespace in which the Online Boutique resources are to be deployed"
  default     = "default"
}

variable "namespace-monitoring" {
  type        = string
  description = "Kubernetes Namespace in which the loki resources are to be deployed"
  default     = "monitoring"
}

variable "filepath_manifest" {
  type        = string
  description = "Path to Online Boutique's Kubernetes resources, written using Kustomize"
  default     = "../kustomize/"
}

variable "filepath_manifest_prometheus-CRD" {
  type        = string
  description = "Path to Online Boutique's Kubernetes resources, written using Kustomize"
  default     = "../manifests/setup/"
}

variable "filepath_manifest_prometheus-stack" {
  type        = string
  description = "Path to Online Boutique's Kubernetes resources, written using Kustomize"
  default     = "../manifests/"
}

variable "filepath_manifest_loki" {
  type        = string
  description = "Path to Online Boutique's loki, written using Kustomize"
  default     = "../kustomize-loki/"
}

variable "memorystore" {
  type        = bool
  description = "If true, Online Boutique's in-cluster Redis cache will be replaced with a Google Cloud Memorystore Redis cache"
}

variable "skip_provisioners" {
  type        = bool
  description = "Flag to skip all local-exec provisioners. It breaks `stub_domains` and `upstream_nameservers` variables functionality."
  default     = true
}

  