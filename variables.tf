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
# Input Variables
##############################################################################

#######################################
# Core Configuration
#######################################

variable "resource_group_id" {
  description = "ID of the IBM Cloud resource group where resources will be created"
  type        = string
}

variable "region" {
  description = "IBM Cloud region where resources will be deployed (e.g., 'us-south', 'eu-de')"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where TFE will be deployed"
  type        = string
}

variable "friendly_name_prefix" {
  description = "Prefix for resource names (lowercase, alphanumeric, hyphens only)"
  type        = string
  default     = null

  validation {
    condition     = var.friendly_name_prefix == null || can(regex("^[a-z][a-z0-9-]*$", var.friendly_name_prefix))
    error_message = "friendly_name_prefix must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "common_tags" {
  description = "List of tags to apply to all resources for cost allocation and organization"
  type        = list(string)
  default     = []
}

#######################################
# Deployment Configuration
#######################################

variable "tfe_operational_mode" {
  description = "TFE operational mode: 'external' (single instance) or 'active-active' (multi-instance with Redis)"
  type        = string
  default     = "external"

  validation {
    condition     = contains(["external", "active-active"], var.tfe_operational_mode)
    error_message = "tfe_operational_mode must be 'external' or 'active-active'."
  }
}

variable "deployment_size" {
  description = "Preset deployment size: 'small', 'medium', 'large', or 'custom'. Determines instance profiles and database sizing."
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["small", "medium", "large", "custom"], var.deployment_size)
    error_message = "deployment_size must be 'small', 'medium', 'large', or 'custom'."
  }
}

variable "network_connectivity" {
  description = "Network connectivity mode: 'public' (internet-facing), 'hybrid' (private backend, public LB), or 'private' (fully private)"
  type        = string
  default     = "hybrid"

  validation {
    condition     = contains(["public", "hybrid", "private"], var.network_connectivity)
    error_message = "network_connectivity must be 'public', 'hybrid', or 'private'."
  }
}

variable "tfe_hostname" {
  description = "Fully qualified domain name for TFE (e.g., 'tfe.example.com'). Must match TLS certificate."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.tfe_hostname)) && length(var.tfe_hostname) <= 253
    error_message = "tfe_hostname must be a valid FQDN (max 253 characters)."
  }
}

variable "tfe_image_repository" {
  description = "Container registry URL for TFE image (default: HashiCorp registry)"
  type        = string
  default     = "images.releases.hashicorp.com/hashicorp/terraform-enterprise"
}

variable "tfe_image_tag" {
  description = "TFE container image tag/version (e.g., 'v202401-1')"
  type        = string
  default     = "latest"
}

#######################################
# Compute Configuration
#######################################

variable "instance_profile" {
  description = "VSI instance profile (only used when deployment_size = 'custom'). Must meet TFE minimum: 4 vCPU, 16GB RAM."
  type        = string
  default     = "bx2-8x32"
}

variable "instance_count" {
  description = "Number of TFE instances (must be 1 for 'external' mode, >= 2 for 'active-active' mode)"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

variable "image_id" {
  description = "ID of the VSI base image (Ubuntu 22.04 LTS / RHEL 8+ / Rocky Linux 8+ recommended)"
  type        = string
  default     = null
}

variable "ssh_key_ids" {
  description = "List of SSH key names for VSI access"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs for TFE compute instances (must span multiple availability zones for HA)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "At least one subnet ID is required."
  }
}

#######################################
# Load Balancer Configuration
#######################################

variable "lb_subnet_ids" {
  description = "List of subnet IDs for load balancer (must span multiple availability zones)"
  type        = list(string)

  validation {
    condition     = length(var.lb_subnet_ids) >= 1
    error_message = "At least one load balancer subnet ID is required."
  }
}

variable "tls_certificate_crn" {
  description = "CRN of the TLS certificate in Secrets Manager for HTTPS listener"
  type        = string

  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tls_certificate_crn))
    error_message = "tls_certificate_crn must be a valid Secrets Manager CRN."
  }
}

variable "allowed_ingress_cidrs" {
  description = "List of CIDR blocks allowed to access TFE (e.g., ['10.0.0.0/8', '172.16.0.0/12'])"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.allowed_ingress_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All entries in allowed_ingress_cidrs must be valid CIDR blocks."
  }
}

#######################################
# Database Configuration
#######################################

variable "database_version" {
  description = "PostgreSQL version (14 or higher required by TFE)"
  type        = string
  default     = "14"
}

variable "database_cpu" {
  description = "Database CPU allocation (only used when deployment_size = 'custom')"
  type        = number
  default     = 4
}

variable "database_memory" {
  description = "Database memory allocation in MB (only used when deployment_size = 'custom')"
  type        = number
  default     = 16384
}

variable "database_backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7

  validation {
    condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 35
    error_message = "database_backup_retention_days must be between 1 and 35."
  }
}

variable "database_password_secret_crn" {
  description = "CRN of the database admin password secret in Secrets Manager"
  type        = string

  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.database_password_secret_crn))
    error_message = "database_password_secret_crn must be a valid Secrets Manager CRN."
  }
}

#######################################
# Redis Configuration (Active-Active Only)
#######################################

variable "redis_memory_mb" {
  description = "Redis memory allocation in MB (only used when deployment_size = 'custom' and tfe_operational_mode = 'active-active')"
  type        = number
  default     = 12288
}

variable "redis_password_secret_crn" {
  description = "CRN of the Redis password secret in Secrets Manager (required for active-active mode)"
  type        = string
  default     = null

  validation {
    condition     = var.redis_password_secret_crn == null || can(regex("^crn:v1:bluemix:public:secrets-manager:", var.redis_password_secret_crn))
    error_message = "redis_password_secret_crn must be a valid Secrets Manager CRN or null."
  }
}

#######################################
# Object Storage Configuration
#######################################

variable "cos_bucket_name" {
  description = "Name of the Object Storage bucket for TFE artifacts and state files"
  type        = string
}

variable "cos_storage_class" {
  description = "Storage class for the COS bucket (standard, vault, cold, flex)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "vault", "cold", "flex"], var.cos_storage_class)
    error_message = "cos_storage_class must be 'standard', 'vault', 'cold', or 'flex'."
  }
}

variable "kms_key_crn" {
  description = "CRN of the Key Protect or HPCS key for encryption at rest"
  type        = string

  validation {
    condition     = can(regex("^crn:v1:bluemix:public:(kms|hs-crypto):", var.kms_key_crn))
    error_message = "kms_key_crn must be a valid Key Protect or HPCS CRN."
  }
}

#######################################
# Secrets Configuration
#######################################

variable "tfe_license_secret_crn" {
  description = "CRN of the TFE license file secret in Secrets Manager"
  type        = string

  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tfe_license_secret_crn))
    error_message = "tfe_license_secret_crn must be a valid Secrets Manager CRN."
  }
}

variable "tfe_encryption_password_secret_crn" {
  description = "CRN of the TFE encryption password secret in Secrets Manager (for securing sensitive data at rest)"
  type        = string

  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tfe_encryption_password_secret_crn))
    error_message = "tfe_encryption_password_secret_crn must be a valid Secrets Manager CRN."
  }
}

variable "secrets_manager_instance_crn" {
  description = "CRN of the Secrets Manager instance containing all secrets"
  type        = string

  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.secrets_manager_instance_crn))
    error_message = "secrets_manager_instance_crn must be a valid Secrets Manager CRN."
  }
}

#######################################
# Autoscaling Configuration (Active-Active Mode)
#######################################

variable "asg_min_size" {
  description = "Minimum number of instances in autoscaling group (active-active mode only)"
  type        = number
  default     = 2

  validation {
    condition     = var.asg_min_size >= 1
    error_message = "asg_min_size must be at least 1."
  }
}

variable "asg_max_size" {
  description = "Maximum number of instances in autoscaling group (active-active mode only)"
  type        = number
  default     = 5

  validation {
    condition     = var.asg_max_size >= var.asg_min_size
    error_message = "asg_max_size must be greater than or equal to asg_min_size."
  }
}

#######################################
# Monitoring and Logging Configuration
#######################################

variable "activity_tracker_crn" {
  description = "CRN of the Activity Tracker instance for audit logging (optional)"
  type        = string
  default     = null

  validation {
    condition     = var.activity_tracker_crn == null || can(regex("^crn:v1:bluemix:public:logdnaat:", var.activity_tracker_crn))
    error_message = "activity_tracker_crn must be a valid Activity Tracker CRN or null."
  }
}

variable "enable_log_forwarding" {
  description = "Enable log forwarding to IBM Log Analysis or COS"
  type        = bool
  default     = false
}

variable "log_forwarding_destination" {
  description = "Log forwarding destination: 'logdna', 'cos', or 'custom'"
  type        = string
  default     = "logdna"

  validation {
    condition     = contains(["logdna", "cos", "custom"], var.log_forwarding_destination)
    error_message = "log_forwarding_destination must be 'logdna', 'cos', or 'custom'."
  }
}

variable "logdna_ingestion_key_secret_crn" {
  description = "CRN of the LogDNA ingestion key secret in Secrets Manager (required if log_forwarding_destination = 'logdna')"
  type        = string
  default     = null

  validation {
    condition     = var.logdna_ingestion_key_secret_crn == null || can(regex("^crn:v1:bluemix:public:secrets-manager:", var.logdna_ingestion_key_secret_crn))
    error_message = "logdna_ingestion_key_secret_crn must be a valid Secrets Manager CRN or null."
  }
}
