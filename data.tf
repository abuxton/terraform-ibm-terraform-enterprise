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
# Data Sources - IBM Cloud lookups and references
##############################################################################

# Get region zones for multi-AZ deployment
data "ibm_is_zones" "regional" {
  region = var.region
}

# Get resource group details
data "ibm_resource_group" "tfe" {
  count = var.resource_group_id != null ? 1 : 0
  name  = var.resource_group_id
}

# VPC data
data "ibm_is_vpc" "tfe" {
  identifier = var.vpc_id
}

# Subnet data for validation
data "ibm_is_subnet" "compute" {
  for_each   = toset(var.subnet_ids)
  identifier = each.value
}

data "ibm_is_subnet" "lb" {
  for_each   = toset(var.lb_subnet_ids)
  identifier = each.value
}

# Get available images (if image_id not provided)
data "ibm_is_images" "tfe" {
  count = var.image_id == null ? 1 : 0
}

# SSH key data
data "ibm_is_ssh_key" "tfe" {
  for_each = toset(var.ssh_key_ids)
  name     = each.value
}

# Database connection information
data "ibm_database_connection" "postgresql" {
  deployment_id = ibm_database.postgresql.id
  user_type     = "database"
  user_id       = "admin"
  endpoint_type = "private" # Use private endpoint for security
}

# Redis connection information (only when active-active mode)
data "ibm_database_connection" "redis" {
  count         = local.is_active_active ? 1 : 0
  deployment_id = ibm_database.redis[0].id
  user_type     = "database"
  user_id       = "admin"
  endpoint_type = "private" # Use private endpoint for security
}
