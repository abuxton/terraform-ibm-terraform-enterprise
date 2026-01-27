/**
 * Copyright 2024 IBM Corp.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

##############################################################################
# Local Values - Common computations and naming conventions
##############################################################################

locals {
  # Naming conventions
  name_prefix = var.friendly_name_prefix != null ? "${var.friendly_name_prefix}-tfe" : "tfe"

  # Common tags for all resources
  common_tags = concat(
    [
      "terraform:true",
      "module:terraform-ibm-terraform-enterprise",
      "tfe_operational_mode:${var.tfe_operational_mode}",
    ],
    var.common_tags
  )

  # Operational mode flags
  is_active_active = var.tfe_operational_mode == "active-active"
  is_external_mode = var.tfe_operational_mode == "external"

  # Instance sizing logic based on deployment_size preset
  instance_profiles = {
    small  = "bx2-4x16"           # 4 vCPU, 16GB RAM
    medium = "bx2-8x32"           # 8 vCPU, 32GB RAM (default)
    large  = "bx2-16x64"          # 16 vCPU, 64GB RAM
    custom = var.instance_profile # Use custom profile if specified
  }

  selected_instance_profile = local.instance_profiles[var.deployment_size]

  # Database sizing
  database_cpu = {
    small  = 2
    medium = 4
    large  = 8
    custom = var.database_cpu
  }

  database_memory = {
    small  = 8192  # 8GB in MB
    medium = 16384 # 16GB in MB
    large  = 32768 # 32GB in MB
    custom = var.database_memory
  }

  selected_database_cpu    = local.database_cpu[var.deployment_size]
  selected_database_memory = local.database_memory[var.deployment_size]

  # Redis sizing (only for active-active mode)
  redis_memory = {
    small  = 8192  # 8GB in MB
    medium = 12288 # 12GB in MB
    large  = 24576 # 24GB in MB
    custom = var.redis_memory_mb
  }

  selected_redis_memory = local.is_active_active ? local.redis_memory[var.deployment_size] : 0

  # Instance count validation
  instance_count = local.is_active_active ? max(var.instance_count, 2) : 1

  # Network connectivity modes
  use_private_endpoints = var.network_connectivity == "private"
  allow_public_access   = var.network_connectivity == "public" || var.network_connectivity == "hybrid"

  # TFE container configuration
  tfe_image = "${var.tfe_image_repository}:${var.tfe_image_tag}"
}
