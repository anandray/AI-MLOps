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

output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.main.id
}

output "efs_file_system_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.main.arn
}

output "efs_dns_name" {
  description = "EFS DNS name"
  value       = aws_efs_file_system.main.dns_name
}

output "efs_security_group_id" {
  description = "EFS security group ID"
  value       = aws_security_group.efs.id
}

output "access_point_ids" {
  description = "Map of access point IDs"
  value       = { for k, v in aws_efs_access_point.main : k => v.id }
}

