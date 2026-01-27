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
# Object Storage Resources - COS Bucket for TFE Artifacts
##############################################################################

#######################################
# Object Storage Instance
#######################################

# Note: This assumes COS instance already exists. If not, uncomment below:
# data "ibm_resource_instance" "cos" {
#   name              = var.cos_instance_name
#   resource_group_id = var.resource_group_id
#   service           = "cloud-object-storage"
# }

# For now, we'll reference the COS instance by resource group
data "ibm_resource_group" "cos" {
  name = var.resource_group_id
}

#######################################
# COS Bucket
#######################################

resource "ibm_cos_bucket" "tfe" {
  bucket_name          = var.cos_bucket_name
  resource_instance_id = data.ibm_resource_group.cos.id
  storage_class        = var.cos_storage_class
  region_location      = var.region

  # Encryption at rest with Key Protect
  key_protect = var.kms_key_crn

  # Retention policy (optional, for compliance)
  # retention_rule {
  #   default   = 90
  #   maximum   = 365
  #   minimum   = 1
  #   permanent = false
  # }

  # Activity tracking
  activity_tracking {
    read_data_events     = true
    write_data_events    = true
    activity_tracker_crn = var.activity_tracker_crn
  }

  # Metrics monitoring
  metrics_monitoring {
    usage_metrics_enabled   = true
    request_metrics_enabled = true
  }

  # Versioning for state file protection
  object_versioning {
    enable = true
  }

  # Lifecycle rules for cost optimization
  # expire_rule {
  #   rule_id = "delete-old-versions"
  #   enable  = true
  #   days    = 90
  #   prefix  = "versions/"
  # }
}

#######################################
# Bucket CORS Configuration (for TFE API access)
#######################################

resource "ibm_cos_bucket_cors_configuration" "tfe" {
  bucket_crn      = ibm_cos_bucket.tfe.crn
  bucket_location = ibm_cos_bucket.tfe.region_location

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["https://${var.tfe_hostname}"]
    expose_headers  = ["ETag", "x-amz-request-id"]
    max_age_seconds = 3600
  }
}
