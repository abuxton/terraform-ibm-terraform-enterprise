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
# Redis Resources - Distributed Caching for Active-Active Mode
##############################################################################

#######################################
# Redis Database (Active-Active Mode Only)
#######################################

resource "ibm_database" "redis" {
  count             = local.is_active_active ? 1 : 0
  name              = "${local.name_prefix}-redis"
  plan              = "standard"
  location          = var.region
  service           = "databases-for-redis"
  version           = "7.2"
  resource_group_id = var.resource_group_id
  tags              = local.common_tags

  # Redis group configuration
  group {
    group_id = "member"
    members {
      allocation_count = 2 # Number of members (always 2 for HA)
    }
    memory {
      allocation_mb = local.selected_redis_memory
    }
    disk {
      allocation_mb = 5120 # 5GB minimum
    }
  }

  # Backup configuration
  backup_encryption_key_crn = var.kms_key_crn

  # Service endpoints
  service_endpoints = local.use_private_endpoints ? "private" : "public-and-private"

  # Encryption
  key_protect_key = var.kms_key_crn

  # Redis configuration parameters
  configuration = jsonencode({
    maxmemory-policy       = "allkeys-lru"
    notify-keyspace-events = "Ex"
    timeout                = 300
  })

  timeouts {
    create = "120m"
    update = "120m"
    delete = "30m"
  }
}
