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

variable "name" {
  description = "Name of the EFS file system"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for mount targets"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access EFS"
  type        = list(string)
  default     = []
}

variable "performance_mode" {
  description = "EFS performance mode (generalPurpose or maxIO)"
  type        = string
  default     = "generalPurpose"
}

variable "throughput_mode" {
  description = "EFS throughput mode (bursting, provisioned)"
  type        = string
  default     = "bursting"
}

variable "provisioned_throughput_in_mibps" {
  description = "Provisioned throughput in MiB/s (required if throughput_mode is provisioned)"
  type        = number
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "transition_to_ia" {
  description = "Transition to IA storage class (AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS)"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "access_points" {
  description = "Map of access point configurations"
  type = map(object({
    posix_user = object({
      gid = number
      uid = number
    })
    root_directory_path = string
    root_directory_creation_info = object({
      owner_gid   = number
      owner_uid   = number
      permissions = string
    })
  }))
  default = {}
}

variable "create_storage_class" {
  description = "Whether to create a Kubernetes StorageClass"
  type        = bool
  default     = true
}

variable "storage_class_name" {
  description = "Name of the StorageClass"
  type        = string
  default     = "efs-sc"
}

variable "is_default_storage_class" {
  description = "Whether this is the default storage class"
  type        = bool
  default     = false
}

variable "provisioning_mode" {
  description = "EFS CSI provisioning mode (efs-ap or efs)"
  type        = string
  default     = "efs-ap"
}

variable "directory_perms" {
  description = "Directory permissions for EFS access points"
  type        = string
  default     = "755"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

