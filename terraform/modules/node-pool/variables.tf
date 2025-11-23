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

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  type        = string
}

variable "cluster_ca" {
  description = "Base64 encoded certificate data"
  type        = string
}

variable "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the node group"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for the node group"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the nodes (EKS optimized AMI)"
  type        = string
  default     = null
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = null
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 10
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 0
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "Disk type (gp3, gp2, io2)"
  type        = string
  default     = "gp3"
}

variable "disk_iops" {
  description = "Disk IOPS (for io2/gp3)"
  type        = number
  default     = null
}

variable "disk_throughput" {
  description = "Disk throughput in MB/s (for gp3)"
  type        = number
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = null
}

variable "node_labels" {
  description = "Labels to apply to nodes"
  type        = map(string)
  default     = {}
}

variable "taint_key" {
  description = "Taint key"
  type        = string
  default     = ""
}

variable "taint_value" {
  description = "Taint value"
  type        = string
  default     = ""
}

variable "taint_effect" {
  description = "Taint effect (NoSchedule, PreferNoSchedule, NoExecute)"
  type        = string
  default     = ""
}

variable "additional_taints" {
  description = "Additional taints to apply"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "bootstrap_extra_args" {
  description = "Extra arguments for bootstrap script"
  type        = string
  default     = ""
}

variable "kubelet_extra_args" {
  description = "Extra arguments for kubelet"
  type        = string
  default     = ""
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs"
  type        = list(string)
  default     = []
}

variable "max_unavailable" {
  description = "Maximum number of unavailable nodes during update"
  type        = number
  default     = null
}

variable "max_unavailable_percentage" {
  description = "Maximum percentage of unavailable nodes during update"
  type        = number
  default     = 1
}

variable "s3_bucket_arns" {
  description = "S3 bucket ARNs for node access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

