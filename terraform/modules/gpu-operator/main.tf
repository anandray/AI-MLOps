# Copyright 2024 [your name/company]
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Add NVIDIA Helm repository
resource "helm_release" "gpu_operator" {
  name       = "gpu-operator"
  repository = "https://nvidia.github.io/gpu-operator"
  chart      = "gpu-operator"
  version    = var.gpu_operator_version
  namespace  = "gpu-operator-resources"
  create_namespace = true

  values = [
    yamlencode({
      operator = {
        defaultRuntime = "containerd"
        runtimeClass    = "nvidia"
      }
      driver = {
        enabled = true
        use_ocp_driver_toolkit = false
      }
      toolkit = {
        enabled = true
      }
      devicePlugin = {
        enabled = true
      }
      migManager = {
        enabled = var.enable_mig
      }
      dcgmExporter = {
        enabled = true
      }
      gfd = {
        enabled = true
      }
      nodeFeatureDiscovery = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.gpu_operator]
}

# Create namespace
resource "kubernetes_namespace" "gpu_operator" {
  metadata {
    name = "gpu-operator-resources"
    labels = {
      name = "gpu-operator-resources"
    }
  }
}

# Apply ClusterPolicy for Time-Slicing
resource "kubernetes_manifest" "cluster_policy_timeslice" {
  count = var.enable_timeslice ? 1 : 0

  manifest = {
    apiVersion = "nvidia.com/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name      = "cluster-policy"
      namespace = "gpu-operator-resources"
    }
    spec = {
      devicePlugin = {
        config = {
          name = "default"
          sharing = {
            timeSlicing = {
              resources = [
                {
                  name     = "nvidia.com/gpu"
                  replicas = var.timeslice_replicas
                }
              ]
            }
          }
        }
      }
      dcgmExporter = {
        enabled = true
      }
      driver = {
        enabled = true
      }
      gfd = {
        enabled = true
      }
      migManager = {
        enabled = false
      }
      toolkit = {
        enabled = true
      }
    }
  }

  depends_on = [helm_release.gpu_operator]
}

# Apply ClusterPolicy for MIG
resource "kubernetes_manifest" "cluster_policy_mig" {
  count = var.enable_mig ? 1 : 0

  manifest = {
    apiVersion = "nvidia.com/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name      = "cluster-policy-mig"
      namespace = "gpu-operator-resources"
    }
    spec = {
      devicePlugin = {
        config = {
          name = "default"
          sharing = {
            migStrategy = "mixed"
          }
        }
      }
      migManager = {
        enabled = true
        config = {
          name = "default"
          migConfigs = {
            "mixed-3g40gb-2g20gb" = [
              {
                devices     = "all"
                migEnabled  = true
                deviceFilter = "0"
                migDevices = {
                  "3g.40gb" = 1
                  "2g.20gb" = 2
                }
              }
            ]
          }
        }
      }
      dcgmExporter = {
        enabled = true
      }
      driver = {
        enabled = true
      }
      gfd = {
        enabled = true
      }
      toolkit = {
        enabled = true
      }
    }
  }

  depends_on = [helm_release.gpu_operator]
}

