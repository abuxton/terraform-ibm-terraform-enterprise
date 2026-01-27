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
# Compute Resources - VSI Instance Group and Instances
##############################################################################

#######################################
# Instance Template
#######################################

resource "ibm_is_instance_template" "tfe" {
  name    = "${local.name_prefix}-instance-template"
  image   = var.image_id != null ? var.image_id : data.ibm_is_images.tfe[0].images[0].id
  profile = local.selected_instance_profile
  vpc     = var.vpc_id
  zone    = data.ibm_is_zones.regional.zones[0]

  primary_network_interface {
    subnet          = var.subnet_ids[0]
    security_groups = [ibm_is_security_group.compute.id]
  }

  keys = [for key_name in var.ssh_key_ids : data.ibm_is_ssh_key.tfe[key_name].id]

  # User data script for TFE installation and configuration
  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    tfe_hostname                       = var.tfe_hostname
    tfe_operational_mode               = var.tfe_operational_mode
    tfe_image                          = local.tfe_image
    tfe_license_secret_crn             = var.tfe_license_secret_crn
    tfe_encryption_password_secret_crn = var.tfe_encryption_password_secret_crn
    database_host                      = ibm_database.postgresql.connectionstrings[0].hosts[0].hostname
    database_port                      = ibm_database.postgresql.connectionstrings[0].hosts[0].port
    database_name                      = ibm_database.postgresql.name
    database_password_secret_crn       = var.database_password_secret_crn
    cos_bucket_name                    = var.cos_bucket_name
    cos_region                         = var.region
    secrets_manager_region             = var.region
    is_active_active                   = local.is_active_active
    redis_host                         = local.is_active_active ? ibm_database.redis[0].connectionstrings[0].hosts[0].hostname : ""
    redis_port                         = local.is_active_active ? ibm_database.redis[0].connectionstrings[0].hosts[0].port : 0
    redis_password_secret_crn          = local.is_active_active ? var.redis_password_secret_crn : ""
  })

  boot_volume {
    name = "${local.name_prefix}-boot-volume"
    size = 100
  }

  resource_group = var.resource_group_id
  tags           = local.common_tags
}

#######################################
# Instance Group (for autoscaling)
#######################################

resource "ibm_is_instance_group" "tfe" {
  name               = "${local.name_prefix}-instance-group"
  instance_template  = ibm_is_instance_template.tfe.id
  instance_count     = local.instance_count
  subnets            = var.subnet_ids
  load_balancer      = ibm_is_lb.tfe.id
  load_balancer_pool = ibm_is_lb_pool.tfe.pool_id
  application_port   = 8080

  resource_group = var.resource_group_id
  tags           = local.common_tags
}

#######################################
# Autoscaling Policies (Active-Active Mode)
#######################################

resource "ibm_is_instance_group_manager" "tfe" {
  count                = local.is_active_active ? 1 : 0
  name                 = "${local.name_prefix}-autoscaler"
  instance_group       = ibm_is_instance_group.tfe.id
  manager_type         = "autoscale"
  enable_manager       = true
  max_membership_count = var.asg_max_size
  min_membership_count = var.asg_min_size
}

# CPU utilization policy
resource "ibm_is_instance_group_manager_policy" "cpu" {
  count                  = local.is_active_active ? 1 : 0
  instance_group         = ibm_is_instance_group.tfe.id
  instance_group_manager = ibm_is_instance_group_manager.tfe[0].manager_id
  metric_type            = "cpu"
  metric_value           = 70
  policy_type            = "target"
  name                   = "${local.name_prefix}-cpu-policy"
}
