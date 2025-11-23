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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Backend configuration - uncomment and configure after creating S3 bucket
  # backend "s3" {
  #   bucket = "ai-mlops-terraform-state"
  #   key    = "production/terraform.tfstate"
  #   region = "us-west-2"
  #   # Optional: enable versioning and encryption
  #   # dynamodb_table = "terraform-state-lock"
  #   # encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "production"
      Project     = "ai-mlops"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Kubernetes and Helm providers are configured after cluster creation
# Uncomment these after the EKS cluster is created, or use them in a separate apply
# data "aws_eks_cluster" "main" {
#   name = module.eks_cluster.cluster_name
# }
# 
# data "aws_eks_cluster_auth" "main" {
#   name = module.eks_cluster.cluster_name
# }
# 
# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.main.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
#   token                  = data.aws_eks_cluster_auth.main.token
# }
# 
# provider "helm" {
#   kubernetes {
#     host                   = data.aws_eks_cluster.main.endpoint
#     cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
#     token                  = data.aws_eks_cluster_auth.main.token
#   }
# }

# EKS Cluster
module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name         = var.cluster_name
  kubernetes_version   = var.kubernetes_version
  subnet_ids           = var.subnet_ids
  vpc_id               = var.vpc_id
  public_endpoint      = var.public_endpoint
  public_access_cidrs  = var.public_access_cidrs
  allowed_cidr_blocks  = var.allowed_cidr_blocks
  enabled_cluster_log_types = var.enabled_cluster_log_types
  log_retention_days   = var.log_retention_days

  tags = var.tags
}

# Get EKS optimized AMI
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2/recommended/release_version"
}

data "aws_ssm_parameter" "eks_ami_id" {
  name = "/aws/service/eks/optimized-ami/${var.kubernetes_version}/amazon-linux-2/recommended/image_id"
}

# CPU Node Pool
module "cpu_node_pool" {
  source = "../../modules/node-pool"

  cluster_name              = module.eks_cluster.cluster_name
  node_pool_name            = "cpu"
  cluster_endpoint          = module.eks_cluster.cluster_endpoint
  cluster_ca                = module.eks_cluster.cluster_certificate_authority_data
  cluster_security_group_id = module.eks_cluster.cluster_security_group_id
  subnet_ids                = var.subnet_ids
  instance_type             = var.cpu_instance_type
  ami_id                    = data.aws_ssm_parameter.eks_ami_id.value
  desired_size              = var.cpu_desired_size
  max_size                  = var.cpu_max_size
  min_size                  = var.cpu_min_size
  disk_size                 = var.cpu_disk_size
  kubernetes_version        = var.kubernetes_version
  node_labels = {
    "workload-type" = "control"
    "node-type"     = "cpu"
  }
  s3_bucket_arns = var.s3_bucket_arns

  tags = var.tags
}

# A100 Time-Slicing Node Pool
module "a100_timeslice_node_pool" {
  source = "../../modules/node-pool"

  cluster_name              = module.eks_cluster.cluster_name
  node_pool_name            = "a100-timeslice"
  cluster_endpoint          = module.eks_cluster.cluster_endpoint
  cluster_ca                = module.eks_cluster.cluster_certificate_authority_data
  cluster_security_group_id = module.eks_cluster.cluster_security_group_id
  subnet_ids                = var.subnet_ids
  instance_type             = var.a100_instance_type
  ami_id                    = data.aws_ssm_parameter.eks_ami_id.value
  desired_size              = var.a100_timeslice_desired_size
  max_size                  = var.a100_timeslice_max_size
  min_size                  = var.a100_timeslice_min_size
  disk_size                 = var.gpu_disk_size
  kubernetes_version        = var.kubernetes_version
  node_labels = {
    "workload-type" = "research"
    "node-type"     = "gpu"
    "gpu-type"      = "a100"
    "gpu-sharing"   = "timeslice"
  }
  taint_key    = "gpu"
  taint_value  = "true"
  taint_effect = "NO_SCHEDULE"
  kubelet_extra_args = "--register-with-taints=gpu=true:NoSchedule"
  s3_bucket_arns = var.s3_bucket_arns

  tags = var.tags
}

# A100 MIG Node Pool (3g.40gb)
module "a100_mig_3g40gb_node_pool" {
  source = "../../modules/node-pool"

  cluster_name              = module.eks_cluster.cluster_name
  node_pool_name            = "a100-mig-3g40gb"
  cluster_endpoint          = module.eks_cluster.cluster_endpoint
  cluster_ca                = module.eks_cluster.cluster_certificate_authority_data
  cluster_security_group_id = module.eks_cluster.cluster_security_group_id
  subnet_ids                = var.subnet_ids
  instance_type             = var.a100_instance_type
  ami_id                    = data.aws_ssm_parameter.eks_ami_id.value
  desired_size              = var.a100_mig_desired_size
  max_size                  = var.a100_mig_max_size
  min_size                  = var.a100_mig_min_size
  disk_size                 = var.gpu_disk_size
  kubernetes_version        = var.kubernetes_version
  node_labels = {
    "workload-type" = "production-inference"
    "node-type"     = "gpu"
    "gpu-type"      = "a100"
    "gpu-sharing"   = "mig"
    "mig-profile"   = "3g.40gb"
  }
  taint_key    = "gpu"
  taint_value  = "mig"
  taint_effect = "NO_SCHEDULE"
  kubelet_extra_args = "--register-with-taints=gpu=mig:NoSchedule"
  s3_bucket_arns = var.s3_bucket_arns

  tags = var.tags
}

# H100 Time-Slicing Node Pool
module "h100_timeslice_node_pool" {
  source = "../../modules/node-pool"

  cluster_name              = module.eks_cluster.cluster_name
  node_pool_name            = "h100-timeslice"
  cluster_endpoint          = module.eks_cluster.cluster_endpoint
  cluster_ca                = module.eks_cluster.cluster_certificate_authority_data
  cluster_security_group_id = module.eks_cluster.cluster_security_group_id
  subnet_ids                = var.subnet_ids
  instance_type             = var.h100_instance_type
  ami_id                    = data.aws_ssm_parameter.eks_ami_id.value
  desired_size              = var.h100_timeslice_desired_size
  max_size                  = var.h100_timeslice_max_size
  min_size                  = var.h100_timeslice_min_size
  disk_size                 = var.gpu_disk_size
  kubernetes_version        = var.kubernetes_version
  node_labels = {
    "workload-type" = "training"
    "node-type"     = "gpu"
    "gpu-type"      = "h100"
    "gpu-sharing"   = "timeslice"
  }
  taint_key    = "gpu"
  taint_value  = "h100"
  taint_effect = "NO_SCHEDULE"
  kubelet_extra_args = "--register-with-taints=gpu=h100:NoSchedule"
  s3_bucket_arns = var.s3_bucket_arns

  tags = var.tags
}

# Storage - EFS for shared datasets and models
module "efs_storage" {
  source = "../../modules/storage"

  name       = "${var.cluster_name}-efs"
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids
  allowed_cidr_blocks = concat(
    [for s in data.aws_subnet.subnets : s.cidr_block],
    var.additional_efs_cidr_blocks
  )
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  kms_key_id       = module.eks_cluster.kms_key_arn

  access_points = {
    datasets = {
      posix_user = {
        gid = 1000
        uid = 1000
      }
      root_directory_path = "/datasets"
      root_directory_creation_info = {
        owner_gid   = 1000
        owner_uid   = 1000
        permissions = "755"
      }
    }
    models = {
      posix_user = {
        gid = 1000
        uid = 1000
      }
      root_directory_path = "/models"
      root_directory_creation_info = {
        owner_gid   = 1000
        owner_uid   = 1000
        permissions = "755"
      }
    }
    checkpoints = {
      posix_user = {
        gid = 1000
        uid = 1000
      }
      root_directory_path = "/checkpoints"
      root_directory_creation_info = {
        owner_gid   = 1000
        owner_uid   = 1000
        permissions = "755"
      }
    }
  }

  tags = var.tags
}

data "aws_subnet" "subnets" {
  count = length(var.subnet_ids)
  id    = var.subnet_ids[count.index]
}

