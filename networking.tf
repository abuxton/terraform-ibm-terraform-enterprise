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
# Security Groups and Network ACLs
##############################################################################

#######################################
# Compute Security Group
#######################################

resource "ibm_is_security_group" "compute" {
  name           = "${local.name_prefix}-compute-sg"
  vpc            = var.vpc_id
  resource_group = var.resource_group_id
  tags           = local.common_tags
}

# Allow HTTPS from load balancer
resource "ibm_is_security_group_rule" "compute_ingress_https" {
  group     = ibm_is_security_group.compute.id
  direction = "inbound"
  remote    = ibm_is_security_group.load_balancer.id
  tcp {
    port_min = 443
    port_max = 443
  }
}

# Allow HTTP from load balancer (for health checks)
resource "ibm_is_security_group_rule" "compute_ingress_http" {
  group     = ibm_is_security_group.compute.id
  direction = "inbound"
  remote    = ibm_is_security_group.load_balancer.id
  tcp {
    port_min = 8080
    port_max = 8080
  }
}

# Allow SSH from allowed CIDRs (for admin access)
resource "ibm_is_security_group_rule" "compute_ingress_ssh" {
  for_each  = toset(var.allowed_ingress_cidrs)
  group     = ibm_is_security_group.compute.id
  direction = "inbound"
  remote    = each.value
  tcp {
    port_min = 22
    port_max = 22
  }
}

# Allow all outbound traffic (for package installation, Docker pulls, etc.)
resource "ibm_is_security_group_rule" "compute_egress_all" {
  group     = ibm_is_security_group.compute.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

#######################################
# Load Balancer Security Group
#######################################

resource "ibm_is_security_group" "load_balancer" {
  name           = "${local.name_prefix}-lb-sg"
  vpc            = var.vpc_id
  resource_group = var.resource_group_id
  tags           = local.common_tags
}

# Allow HTTPS from allowed CIDRs
resource "ibm_is_security_group_rule" "lb_ingress_https" {
  for_each  = toset(var.allowed_ingress_cidrs)
  group     = ibm_is_security_group.load_balancer.id
  direction = "inbound"
  remote    = each.value
  tcp {
    port_min = 443
    port_max = 443
  }
}

# Allow outbound to compute instances
resource "ibm_is_security_group_rule" "lb_egress_compute" {
  group     = ibm_is_security_group.load_balancer.id
  direction = "outbound"
  remote    = ibm_is_security_group.compute.id
}

#######################################
# Database Security Group
#######################################

resource "ibm_is_security_group" "database" {
  name           = "${local.name_prefix}-db-sg"
  vpc            = var.vpc_id
  resource_group = var.resource_group_id
  tags           = local.common_tags
}

# Allow PostgreSQL from compute instances only
resource "ibm_is_security_group_rule" "db_ingress_postgres" {
  group     = ibm_is_security_group.database.id
  direction = "inbound"
  remote    = ibm_is_security_group.compute.id
  tcp {
    port_min = 5432
    port_max = 5432
  }
}

# Allow Redis from compute instances (active-active mode only)
resource "ibm_is_security_group_rule" "db_ingress_redis" {
  count     = local.is_active_active ? 1 : 0
  group     = ibm_is_security_group.database.id
  direction = "inbound"
  remote    = ibm_is_security_group.compute.id
  tcp {
    port_min = 6379
    port_max = 6379
  }
}

# No outbound rules needed for database (databases don't initiate connections)
