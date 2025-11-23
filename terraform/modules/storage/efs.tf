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
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# EFS File System
resource "aws_efs_file_system" "main" {
  creation_token                  = var.name
  performance_mode                = var.performance_mode
  throughput_mode                 = var.throughput_mode
  provisioned_throughput_in_mibps = var.provisioned_throughput_in_mibps
  encrypted                       = true
  kms_key_id                      = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "main" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# EFS Security Group
resource "aws_security_group" "efs" {
  name        = "${var.name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "NFS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-efs-sg"
    }
  )
}

# EFS Access Point
resource "aws_efs_access_point" "main" {
  for_each = var.access_points

  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = each.value.posix_user.gid
    uid = each.value.posix_user.uid
  }

  root_directory {
    path = each.value.root_directory_path
    creation_info {
      owner_gid   = each.value.root_directory_creation_info.owner_gid
      owner_uid   = each.value.root_directory_creation_info.owner_uid
      permissions = each.value.root_directory_creation_info.permissions
    }
  }

  tags = merge(
    var.tags,
    {
      Name = each.key
    }
  )
}

# Kubernetes StorageClass for EFS CSI Driver
resource "kubernetes_storage_class" "efs" {
  count = var.create_storage_class ? 1 : 0

  metadata {
    name = var.storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = var.is_default_storage_class ? "true" : "false"
    }
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"

  parameters = {
    provisioningMode = var.provisioning_mode
    fileSystemId     = aws_efs_file_system.main.id
    directoryPerms   = var.directory_perms
  }

  depends_on = [aws_efs_file_system.main]
}

