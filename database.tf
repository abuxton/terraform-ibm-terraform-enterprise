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
# Database Resources - PostgreSQL for TFE
##############################################################################

#######################################
# PostgreSQL Database
#######################################

resource "ibm_database" "postgresql" {
  name              = "${local.name_prefix}-postgresql"
  plan              = "standard"
  location          = var.region
  service           = "databases-for-postgresql"
  version           = var.database_version
  resource_group_id = var.resource_group_id
  tags              = local.common_tags

  # Database group configuration (CPU and Memory)
  group {
    group_id = "member"
    members {
      allocation_count = 2 # Number of members (always 2 for HA)
    }
    cpu {
      allocation_count = local.selected_database_cpu
    }
    memory {
      allocation_mb = local.selected_database_memory
    }
    disk {
      allocation_mb = 20480 # 20GB minimum, will auto-scale
    }
  }

  # Backup configuration
  backup_id                            = null
  backup_encryption_key_crn            = var.kms_key_crn
  point_in_time_recovery_deployment_id = null
  point_in_time_recovery_time          = null

  # Auto-scaling configuration
  auto_scaling {
    disk {
      capacity_enabled             = true
      free_space_less_than_percent = 10
      io_above_percent             = 90
      io_enabled                   = true
      io_over_period               = "15m"
      rate_increase_percent        = 10
      rate_limit_mb_per_member     = 3670016 # ~3.5TB max
      rate_period_seconds          = 900
      rate_units                   = "mb"
    }
    memory {
      io_above_percent         = 90
      io_enabled               = true
      io_over_period           = "15m"
      rate_increase_percent    = 10
      rate_limit_mb_per_member = 114688
      rate_period_seconds      = 900
      rate_units               = "mb"
    }
  }

  # Service endpoints (private if network_connectivity is private/hybrid)
  service_endpoints = local.use_private_endpoints ? "private" : "public-and-private"

  # Configuration parameters for TFE
  configuration = jsonencode({
    max_connections           = 200
    max_prepared_transactions = 0
    shared_buffers            = 16
    effective_cache_size      = 32
    work_mem                  = 16
    maintenance_work_mem      = 16
  })

  # Encryption
  key_protect_key = var.kms_key_crn

  timeouts {
    create = "120m" # Database provisioning can take 15-20 minutes
    update = "120m"
    delete = "30m"
  }
}

#######################################
# Database Connection Configuration
#######################################

# Store database credentials securely (not in Terraform state)
# Credentials are retrieved from Secrets Manager at runtime by VSI
