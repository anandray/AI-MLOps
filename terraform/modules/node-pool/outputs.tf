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

output "node_group_arn" {
  description = "ARN of the node group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_id" {
  description = "ID of the node group"
  value       = aws_eks_node_group.main.id
}

output "node_group_status" {
  description = "Status of the node group"
  value       = aws_eks_node_group.main.status
}

output "iam_role_arn" {
  description = "IAM role ARN for the node group"
  value       = aws_iam_role.node_group.arn
}

output "iam_role_name" {
  description = "IAM role name for the node group"
  value       = aws_iam_role.node_group.name
}

