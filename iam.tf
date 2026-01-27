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
# IAM Policies and Service Authorizations
##############################################################################

#######################################
# Service Authorizations
#######################################

# Allow VSI to access Object Storage
resource "ibm_iam_authorization_policy" "vsi_to_cos" {
  source_service_name         = "is"
  source_resource_type        = "instance"
  target_service_name         = "cloud-object-storage"
  target_resource_instance_id = var.resource_group_id
  roles                       = ["Writer", "Reader"]
  description                 = "Allow TFE VSI instances to read/write to Object Storage bucket"
}

# Allow VSI to access Secrets Manager
resource "ibm_iam_authorization_policy" "vsi_to_secrets_manager" {
  source_service_name         = "is"
  source_resource_type        = "instance"
  target_service_name         = "secrets-manager"
  target_resource_instance_id = var.secrets_manager_instance_crn
  roles                       = ["SecretsReader"]
  description                 = "Allow TFE VSI instances to read secrets from Secrets Manager"
}

# Allow Object Storage to use Key Protect for encryption
resource "ibm_iam_authorization_policy" "cos_to_kms" {
  source_service_name         = "cloud-object-storage"
  source_resource_instance_id = var.resource_group_id
  target_service_name         = "kms"
  target_resource_instance_id = var.kms_key_crn
  roles                       = ["Reader"]
  description                 = "Allow Object Storage to use Key Protect for encryption at rest"
}

# Allow Database to use Key Protect for encryption
resource "ibm_iam_authorization_policy" "database_to_kms" {
  source_service_name = "databases-for-postgresql"
  target_service_name = "kms"
  roles               = ["Reader"]
  description         = "Allow PostgreSQL database to use Key Protect for encryption at rest"
}

# Allow Redis to use Key Protect (active-active mode only)
resource "ibm_iam_authorization_policy" "redis_to_kms" {
  count               = local.is_active_active ? 1 : 0
  source_service_name = "databases-for-redis"
  target_service_name = "kms"
  roles               = ["Reader"]
  description         = "Allow Redis to use Key Protect for encryption at rest"
}

#######################################
# Service IDs (for programmatic access if needed)
#######################################

# Service ID for TFE application
resource "ibm_iam_service_id" "tfe" {
  name        = "${local.name_prefix}-service-id"
  description = "Service ID for TFE application access to IBM Cloud services"
  tags        = local.common_tags
}

# Policy: Allow Service ID to access Object Storage
resource "ibm_iam_service_policy" "tfe_cos_access" {
  iam_service_id = ibm_iam_service_id.tfe.id
  roles          = ["Writer", "Reader", "ContentReader"]

  resources {
    service              = "cloud-object-storage"
    resource_instance_id = var.resource_group_id
  }
}

# Policy: Allow Service ID to access Secrets Manager
resource "ibm_iam_service_policy" "tfe_secrets_access" {
  iam_service_id = ibm_iam_service_id.tfe.id
  roles          = ["SecretsReader"]

  resources {
    service              = "secrets-manager"
    resource_instance_id = var.secrets_manager_instance_crn
  }
}

# API Key for Service ID (stored in outputs as sensitive)
resource "ibm_iam_service_api_key" "tfe" {
  name           = "${local.name_prefix}-api-key"
  iam_service_id = ibm_iam_service_id.tfe.iam_id
  description    = "API key for TFE application to authenticate with IBM Cloud services"
  store_value    = true
}
