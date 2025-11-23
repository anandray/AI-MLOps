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
  }
}

# EKS Node Group IAM Role
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-${var.node_pool_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node_group.name
}

# Additional IAM policies for GPU workloads
resource "aws_iam_role_policy" "node_group_s3_access" {
  name = "${var.cluster_name}-${var.node_pool_name}-s3-access"
  role = aws_iam_role.node_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = var.s3_bucket_arns
      }
    ]
  })
}

# Launch Template
resource "aws_launch_template" "node_group" {
  name_prefix   = "${var.cluster_name}-${var.node_pool_name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = concat(
    [var.cluster_security_group_id],
    var.additional_security_group_ids
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.disk_size
      volume_type           = var.disk_type
      iops                  = var.disk_iops
      throughput            = var.disk_throughput
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name        = var.cluster_name
    cluster_endpoint    = var.cluster_endpoint
    cluster_ca          = var.cluster_ca
    bootstrap_extra_args = var.bootstrap_extra_args
    kubelet_extra_args  = var.kubelet_extra_args
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name                                        = "${var.cluster_name}-${var.node_pool_name}"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
        "k8s.io/cluster-autoscaler/enabled"         = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      },
      var.node_labels
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_pool_name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version

  launch_template {
    id      = aws_launch_template.node_group.id
    version = aws_launch_template.node_group.latest_version
  }

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable            = var.max_unavailable
    max_unavailable_percentage = var.max_unavailable_percentage
  }

  labels = var.node_labels

  dynamic "taint" {
    for_each = var.taint_key != "" ? [1] : []
    content {
      key    = var.taint_key
      value  = var.taint_value
      effect = var.taint_effect
    }
  }

  dynamic "taint" {
    for_each = var.additional_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-${var.node_pool_name}"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

