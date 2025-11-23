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

variable "gpu_operator_version" {
  description = "Version of GPU Operator to install"
  type        = string
  default     = "23.9.0"
}

variable "enable_timeslice" {
  description = "Enable time-slicing configuration"
  type        = bool
  default     = true
}

variable "enable_mig" {
  description = "Enable MIG configuration"
  type        = bool
  default     = true
}

variable "timeslice_replicas" {
  description = "Number of replicas per GPU for time-slicing"
  type        = number
  default     = 3
}

