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
  default     = "ai-mlops-production"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "public_endpoint" {
  description = "Whether the cluster API server endpoint is publicly accessible"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public endpoint"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = []
}

variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# CPU Node Pool
variable "cpu_instance_type" {
  description = "EC2 instance type for CPU node pool"
  type        = string
  default     = "m5.4xlarge"
}

variable "cpu_desired_size" {
  description = "Desired number of CPU nodes"
  type        = number
  default     = 2
}

variable "cpu_max_size" {
  description = "Maximum number of CPU nodes"
  type        = number
  default     = 10
}

variable "cpu_min_size" {
  description = "Minimum number of CPU nodes"
  type        = number
  default     = 1
}

variable "cpu_disk_size" {
  description = "Disk size for CPU nodes (GB)"
  type        = number
  default     = 100
}

# A100 Node Pool (Time-Slicing)
variable "a100_instance_type" {
  description = "EC2 instance type for A100 node pool"
  type        = string
  default     = "p5.48xlarge" # 8x A100 80GB
}

variable "a100_timeslice_desired_size" {
  description = "Desired number of A100 time-slice nodes"
  type        = number
  default     = 1
}

variable "a100_timeslice_max_size" {
  description = "Maximum number of A100 time-slice nodes"
  type        = number
  default     = 5
}

variable "a100_timeslice_min_size" {
  description = "Minimum number of A100 time-slice nodes"
  type        = number
  default     = 0
}

# A100 Node Pool (MIG)
variable "a100_mig_desired_size" {
  description = "Desired number of A100 MIG nodes"
  type        = number
  default     = 1
}

variable "a100_mig_max_size" {
  description = "Maximum number of A100 MIG nodes"
  type        = number
  default     = 3
}

variable "a100_mig_min_size" {
  description = "Minimum number of A100 MIG nodes"
  type        = number
  default     = 1
}

# H100 Node Pool (Time-Slicing)
variable "h100_instance_type" {
  description = "EC2 instance type for H100 node pool"
  type        = string
  default     = "p5.48xlarge" # 8x H100 80GB
}

variable "h100_timeslice_desired_size" {
  description = "Desired number of H100 time-slice nodes"
  type        = number
  default     = 1
}

variable "h100_timeslice_max_size" {
  description = "Maximum number of H100 time-slice nodes"
  type        = number
  default     = 5
}

variable "h100_timeslice_min_size" {
  description = "Minimum number of H100 time-slice nodes"
  type        = number
  default     = 0
}

variable "gpu_disk_size" {
  description = "Disk size for GPU nodes (GB)"
  type        = number
  default     = 500
}

# Storage
variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
}

variable "additional_efs_cidr_blocks" {
  description = "Additional CIDR blocks for EFS access"
  type        = list(string)
  default     = []
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

