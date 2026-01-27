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
# Load Balancer Resources - NLB for TFE Traffic
##############################################################################

#######################################
# Network Load Balancer
#######################################

resource "ibm_is_lb" "tfe" {
  name            = "${local.name_prefix}-lb"
  type            = local.allow_public_access ? "public" : "private"
  subnets         = var.lb_subnet_ids
  security_groups = [ibm_is_security_group.load_balancer.id]
  resource_group  = var.resource_group_id
  tags            = local.common_tags

  # Logging (optional)
  # logging {
  #   datapath {
  #     active = true
  #   }
  # }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

#######################################
# Backend Pool
#######################################

resource "ibm_is_lb_pool" "tfe" {
  name                = "${local.name_prefix}-pool"
  lb                  = ibm_is_lb.tfe.id
  algorithm           = "round_robin"
  protocol            = "https"
  health_delay        = 60
  health_retries      = 5
  health_timeout      = 30
  health_type         = "https"
  health_monitor_url  = "/_health_check"
  health_monitor_port = 8080

  # Session persistence for active-active mode
  session_persistence_type = local.is_active_active ? "source_ip" : null
}

#######################################
# HTTPS Listener (Port 443)
#######################################

resource "ibm_is_lb_listener" "tfe_https" {
  lb                   = ibm_is_lb.tfe.id
  port                 = 443
  protocol             = "https"
  default_pool         = ibm_is_lb_pool.tfe.id
  certificate_instance = var.tls_certificate_crn
  connection_limit     = 2000

  # HTTP/2 support
  accept_proxy_protocol = false
  port_min              = null
  port_max              = null
}

#######################################
# HTTP Redirect Listener (Port 80 → 443)
#######################################

resource "ibm_is_lb_listener" "tfe_http_redirect" {
  count    = local.allow_public_access ? 1 : 0
  lb       = ibm_is_lb.tfe.id
  port     = 80
  protocol = "http"

  # Redirect to HTTPS
  https_redirect {
    http_status_code = 301
    listener         = ibm_is_lb_listener.tfe_https.listener_id
    uri              = "/"
  }
}

#######################################
# Pool Members (managed by instance group)
#######################################

# Instance group automatically manages pool members
# No need for explicit ibm_is_lb_pool_member resources
