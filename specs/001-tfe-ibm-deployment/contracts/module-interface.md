# Module Interface Contract

**Feature**: Terraform Enterprise on IBM Cloud (HVD)  
**Version**: 1.0.0  
**Date**: 2026-01-26

## Overview

This document defines the contract for the `terraform-ibm-terraform-enterprise` root module, specifying required inputs, outputs, and provider constraints. This contract must remain stable across minor version updates to prevent breaking changes for module consumers.

---

## Provider Requirements

```hcl
terraform {
  required_version = ">= 1.9.0"
  
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.70.0"
    }
  }
}
```

**Rationale**:
- Terraform 1.9.0: Provides latest validation features and performance improvements
- IBM Provider 1.70.0: Includes VPC Instance Groups API and Databases v2 API features

---

## Required Input Variables

### Core Deployment Configuration

```hcl
variable "friendly_name_prefix" {
  type        = string
  description = "Prefix for resource naming (e.g., 'prod-tfe'). Must be lowercase alphanumeric with hyphens."
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.friendly_name_prefix))
    error_message = "Must start with lowercase letter, contain only lowercase alphanumeric and hyphens."
  }
}

variable "region" {
  type        = string
  description = "IBM Cloud region for resource deployment (e.g., 'us-south', 'eu-de')"
}

variable "resource_group_id" {
  type        = string
  description = "IBM Cloud resource group ID for all provisioned resources"
}

variable "tfe_hostname" {
  type        = string
  description = "Fully qualified domain name for TFE access (e.g., 'tfe.example.com')"
  
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.tfe_hostname))
    error_message = "Must be valid FQDN with lowercase letters, numbers, hyphens, and dots."
  }
  
  validation {
    condition     = length(var.tfe_hostname) <= 253
    error_message = "FQDN must not exceed 253 characters (DNS limit)."
  }
}
```

### Networking

```hcl
variable "vpc_id" {
  type        = string
  description = "Existing IBM Cloud VPC ID where TFE will be deployed"
}

variable "compute_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for TFE compute instances (should span multiple availability zones)"
  
  validation {
    condition     = length(var.compute_subnet_ids) >= 1
    error_message = "Must provide at least one compute subnet."
  }
}

variable "lb_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for load balancer (should span multiple availability zones)"
  
  validation {
    condition     = length(var.lb_subnet_ids) >= 1
    error_message = "Must provide at least one load balancer subnet."
  }
}

variable "ingress_cidr_blocks_https" {
  type        = list(string)
  description = "CIDR blocks allowed to access TFE via HTTPS (e.g., ['10.0.0.0/8', '0.0.0.0/0'])"
  
  validation {
    condition     = length(var.ingress_cidr_blocks_https) > 0
    error_message = "Must specify at least one allowed CIDR block for HTTPS access."
  }
}
```

### Secrets Management

```hcl
variable "secrets_manager_instance_id" {
  type        = string
  description = "IBM Cloud Secrets Manager instance ID (GUID format)"
}

variable "tfe_license_secret_crn" {
  type        = string
  description = "CRN of secret containing TFE license file (base64-encoded .hclic)"
  
  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tfe_license_secret_crn))
    error_message = "Must be valid Secrets Manager CRN."
  }
}

variable "tls_certificate_secret_crn" {
  type        = string
  description = "CRN of secret containing TLS certificate in PEM format"
  
  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tls_certificate_secret_crn))
    error_message = "Must be valid Secrets Manager CRN."
  }
}

variable "tls_private_key_secret_crn" {
  type        = string
  description = "CRN of secret containing TLS private key in PEM format"
  
  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tls_private_key_secret_crn))
    error_message = "Must be valid Secrets Manager CRN."
  }
}

variable "tfe_encryption_password_secret_crn" {
  type        = string
  description = "CRN of secret containing TFE internal encryption password (32+ characters)"
  
  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tfe_encryption_password_secret_crn))
    error_message = "Must be valid Secrets Manager CRN."
  }
}

variable "database_admin_password_secret_crn" {
  type        = string
  description = "CRN of secret containing PostgreSQL admin password"
  
  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.database_admin_password_secret_crn))
    error_message = "Must be valid Secrets Manager CRN."
  }
}
```

### Encryption

```hcl
variable "kms_key_crn" {
  type        = string
  description = "CRN of IBM Cloud Key Protect or HPCS encryption key for data at rest"
  
  validation {
    condition     = can(regex("^crn:v1:bluemix:public:(kms|hs-crypto):", var.kms_key_crn))
    error_message = "Must be valid Key Protect or Hyper Protect Crypto Services key CRN."
  }
}
```

---

## Optional Input Variables

### TFE Configuration

```hcl
variable "tfe_operational_mode" {
  type        = string
  description = "TFE operational mode: 'external' (single instance) or 'active-active' (multi-instance)"
  default     = "external"
  
  validation {
    condition     = contains(["external", "active-active"], var.tfe_operational_mode)
    error_message = "Must be 'external' or 'active-active'."
  }
}

variable "tfe_instance_count" {
  type        = number
  description = "Number of TFE instances (1 for external, 2+ for active-active)"
  default     = 1
  
  validation {
    condition     = var.tfe_instance_count >= 1
    error_message = "Must be at least 1."
  }
}

variable "tfe_image_tag" {
  type        = string
  description = "TFE container image tag (e.g., 'v202401-1'). Pin to specific version for production."
  default     = "v202401-1"
}

variable "tfe_image_repository" {
  type        = string
  description = "TFE container image repository (use custom registry for air-gapped)"
  default     = "images.releases.hashicorp.com"
}

variable "deployment_size" {
  type        = string
  description = "Preset deployment size: 'small', 'medium', 'large', or 'custom'"
  default     = "medium"
  
  validation {
    condition     = contains(["small", "medium", "large", "custom"], var.deployment_size)
    error_message = "Must be 'small', 'medium', 'large', or 'custom'."
  }
}
```

### Compute

```hcl
variable "instance_profile" {
  type        = string
  description = "VSI instance profile (e.g., 'bx2-8x32'). Override deployment_size preset if specified."
  default     = null
}

variable "instance_image_id" {
  type        = string
  description = "Custom VSI image ID. If null, uses latest Ubuntu 22.04 LTS."
  default     = null
}

variable "ssh_key_ids" {
  type        = list(string)
  description = "List of SSH key IDs for VSI access (for debugging/maintenance)"
  default     = []
}
```

### Database

```hcl
variable "database_version" {
  type        = string
  description = "PostgreSQL version (e.g., '14', '15')"
  default     = "15"
  
  validation {
    condition     = tonumber(var.database_version) >= 14
    error_message = "PostgreSQL version must be 14 or higher for TFE compatibility."
  }
}

variable "database_backup_retention_days" {
  type        = number
  description = "Database backup retention period (1-35 days)"
  default     = 35
  
  validation {
    condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 35
    error_message = "Retention must be between 1 and 35 days."
  }
}
```

### Networking

```hcl
variable "network_connectivity" {
  type        = string
  description = "Network mode: 'public' (all public), 'hybrid' (public LB, private backend), 'private' (all private)"
  default     = "hybrid"
  
  validation {
    condition     = contains(["public", "hybrid", "private"], var.network_connectivity)
    error_message = "Must be 'public', 'hybrid', or 'private'."
  }
}

variable "ingress_cidr_blocks_ssh" {
  type        = list(string)
  description = "CIDR blocks allowed SSH access to VSIs (for management). Empty list disables SSH."
  default     = []
}

variable "enable_metrics_endpoint" {
  type        = bool
  description = "Expose TFE metrics endpoint (port 9091 HTTPS)"
  default     = false
}

variable "metrics_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to scrape metrics endpoint (if enabled)"
  default     = []
}
```

### Observability

```hcl
variable "enable_log_forwarding" {
  type        = bool
  description = "Enable log forwarding to IBM Log Analysis or Cloud Object Storage"
  default     = false
}

variable "log_forwarding_destination" {
  type        = string
  description = "Log destination: 'logdna', 'cos', or 'custom'"
  default     = "logdna"
  
  validation {
    condition     = contains(["logdna", "cos", "custom"], var.log_forwarding_destination)
    error_message = "Must be 'logdna', 'cos', or 'custom'."
  }
}

variable "logdna_instance_crn" {
  type        = string
  description = "IBM Log Analysis instance CRN (required if log_forwarding_destination = 'logdna')"
  default     = null
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable IBM Cloud Monitoring integration"
  default     = false
}

variable "monitoring_instance_crn" {
  type        = string
  description = "IBM Cloud Monitoring instance CRN (required if enable_monitoring = true)"
  default     = null
}
```

### Active-Active Mode (conditional)

```hcl
variable "redis_password_secret_crn" {
  type        = string
  description = "CRN of secret containing Redis password (required if tfe_operational_mode = 'active-active')"
  default     = null
  
  validation {
    condition = (
      var.redis_password_secret_crn == null ||
      can(regex("^crn:v1:bluemix:public:secrets-manager:", var.redis_password_secret_crn))
    )
    error_message = "Must be valid Secrets Manager CRN or null."
  }
}

variable "redis_version" {
  type        = string
  description = "Redis version (e.g., '7.0', '7.2'). Only used in active-active mode."
  default     = "7.2"
}
```

### Resource Tagging

```hcl
variable "common_tags" {
  type        = list(string)
  description = "Tags applied to all resources for cost allocation and governance"
  default     = []
}
```

---

## Output Values

### Primary Endpoints

```hcl
output "tfe_url" {
  description = "TFE application URL (HTTPS)"
  value       = "https://${var.tfe_hostname}"
}

output "tfe_admin_url" {
  description = "URL for initial admin account creation"
  value       = "https://${var.tfe_hostname}/admin/account/new"
}

output "load_balancer_hostname" {
  description = "Load balancer DNS hostname (for DNS configuration)"
  value       = ibm_is_lb.tfe.hostname
}

output "load_balancer_public_ip" {
  description = "Load balancer public IP address (if public LB)"
  value       = var.network_connectivity == "private" ? null : ibm_is_lb.tfe.public_ips[0]
}
```

### Resource Identifiers

```hcl
output "compute_instance_group_id" {
  description = "Instance group ID managing TFE compute instances"
  value       = ibm_is_instance_group.tfe.id
}

output "database_instance_id" {
  description = "PostgreSQL database instance ID"
  value       = ibm_database.postgresql.id
}

output "database_connection_string" {
  description = "Database connection string (sensitive - for debugging only)"
  value       = ibm_database.postgresql.connectionstrings[0].composed
  sensitive   = true
}

output "redis_instance_id" {
  description = "Redis instance ID (null if not active-active)"
  value       = var.tfe_operational_mode == "active-active" ? ibm_database.redis[0].id : null
}

output "object_storage_bucket_name" {
  description = "Object Storage bucket name for TFE artifacts"
  value       = ibm_cos_bucket.tfe.bucket_name
}

output "object_storage_bucket_crn" {
  description = "Object Storage bucket CRN"
  value       = ibm_cos_bucket.tfe.crn
}
```

### Security Group IDs

```hcl
output "compute_security_group_id" {
  description = "Security group ID for TFE compute instances"
  value       = ibm_is_security_group.tfe_compute.id
}

output "load_balancer_security_group_id" {
  description = "Security group ID for load balancer"
  value       = ibm_is_security_group.tfe_lb.id
}

output "database_security_group_id" {
  description = "Security group ID for database and Redis"
  value       = ibm_is_security_group.tfe_database.id
}
```

### Operational Information

```hcl
output "tfe_operational_mode" {
  description = "Configured TFE operational mode"
  value       = var.tfe_operational_mode
}

output "tfe_instance_count" {
  description = "Number of TFE instances deployed"
  value       = var.tfe_instance_count
}

output "deployment_region" {
  description = "IBM Cloud region where resources are deployed"
  value       = var.region
}

output "module_version" {
  description = "Version of this Terraform module"
  value       = "1.0.0"
}
```

---

## Cross-Variable Validation

### Enforced via locals.tf

```hcl
locals {
  # Validate instance count matches operational mode
  validate_instance_count = (
    var.tfe_operational_mode == "external" && var.tfe_instance_count != 1 
    ? file("ERROR: external mode requires exactly 1 instance, got ${var.tfe_instance_count}")
    : var.tfe_operational_mode == "active-active" && var.tfe_instance_count < 2
    ? file("ERROR: active-active mode requires 2+ instances, got ${var.tfe_instance_count}")
    : null
  )
  
  # Validate Redis password provided for active-active
  validate_redis_password = (
    var.tfe_operational_mode == "active-active" && var.redis_password_secret_crn == null
    ? file("ERROR: redis_password_secret_crn required when tfe_operational_mode = 'active-active'")
    : null
  )
  
  # Validate log forwarding configuration
  validate_log_forwarding = (
    var.enable_log_forwarding && var.log_forwarding_destination == "logdna" && var.logdna_instance_crn == null
    ? file("ERROR: logdna_instance_crn required when log_forwarding_destination = 'logdna'")
    : null
  )
  
  # Validate monitoring configuration
  validate_monitoring = (
    var.enable_monitoring && var.monitoring_instance_crn == null
    ? file("ERROR: monitoring_instance_crn required when enable_monitoring = true")
    : null
  )
}
```

---

## Breaking Change Policy

### Semantic Versioning Commitment

- **Patch versions (1.0.x)**: Bug fixes, documentation, internal refactoring. No variable changes.
- **Minor versions (1.x.0)**: New optional variables, new outputs. Existing variables unchanged.
- **Major versions (x.0.0)**: Breaking changes allowed (rename variables, change validation, remove outputs).

### Examples of Breaking Changes

**Requires MAJOR version bump**:
- Renaming variable: `tfe_hostname` → `tfe_fqdn`
- Changing validation: `tfe_instance_count >= 1` → `tfe_instance_count >= 2`
- Removing output: Delete `load_balancer_public_ip`
- Changing output type: `common_tags: list(string)` → `map(string)`
- Changing default: `deployment_size: "medium"` → `"small"`

**Allowed in MINOR version bump**:
- Adding new optional variable with default value
- Adding new output
- Relaxing validation: `>= 1.70.0` → `>= 1.65.0`
- Adding new preset to enum: `deployment_size: ["small", "medium", "large", "xlarge"]`

---

## Module Usage Example

```hcl
module "tfe" {
  source  = "terraform-ibm-modules/terraform-enterprise/ibm"
  version = "~> 1.0"
  
  # Required
  friendly_name_prefix = "prod-tfe"
  region               = "us-south"
  resource_group_id    = "abc123..."
  tfe_hostname         = "tfe.example.com"
  
  # Networking (required)
  vpc_id                     = "r006-abc123..."
  compute_subnet_ids         = ["subnet-abc", "subnet-def", "subnet-ghi"]
  lb_subnet_ids              = ["subnet-jkl", "subnet-mno"]
  ingress_cidr_blocks_https  = ["0.0.0.0/0"]  # Public access
  
  # Secrets (required)
  secrets_manager_instance_id       = "guid-abc123..."
  tfe_license_secret_crn            = "crn:v1:bluemix:public:secrets-manager:..."
  tls_certificate_secret_crn        = "crn:v1:bluemix:public:secrets-manager:..."
  tls_private_key_secret_crn        = "crn:v1:bluemix:public:secrets-manager:..."
  tfe_encryption_password_secret_crn = "crn:v1:bluemix:public:secrets-manager:..."
  database_admin_password_secret_crn = "crn:v1:bluemix:public:secrets-manager:..."
  
  # Encryption (required)
  kms_key_crn = "crn:v1:bluemix:public:kms:..."
  
  # Optional - Deployment configuration
  tfe_operational_mode = "active-active"
  tfe_instance_count   = 3
  deployment_size      = "medium"
  
  # Optional - Active-active configuration
  redis_password_secret_crn = "crn:v1:bluemix:public:secrets-manager:..."
  
  # Optional - Observability
  enable_log_forwarding     = true
  log_forwarding_destination = "logdna"
  logdna_instance_crn       = "crn:v1:bluemix:public:logdna:..."
  enable_monitoring         = true
  monitoring_instance_crn   = "crn:v1:bluemix:public:sysdig-monitor:..."
  
  # Optional - Tagging
  common_tags = [
    "environment:production",
    "application:terraform-enterprise",
    "managed-by:terraform"
  ]
}

output "tfe_url" {
  value = module.tfe.tfe_url
}

output "admin_setup_url" {
  value = module.tfe.tfe_admin_url
}
```

---

## Contract Test Suite

### Required Tests

Module consumers can verify contract compliance with:

```go
// tests/contract/module_interface_test.go
func TestModuleInterface(t *testing.T) {
  t.Run("RequiredVariables", func(t *testing.T) {
    // Verify all required variables are present
  })
  
  t.Run("OutputValues", func(t *testing.T) {
    // Verify all documented outputs are present
  })
  
  t.Run("ProviderVersionConstraints", func(t *testing.T) {
    // Verify Terraform and provider versions match contract
  })
  
  t.Run("VariableValidation", func(t *testing.T) {
    // Test that invalid variable values are rejected
  })
}
```

---

## Summary

This contract defines:
- **31 input variables** (10 required, 21 optional)
- **16 output values**
- **5 cross-variable validations**
- **Semantic versioning commitment** for backward compatibility

All changes to this contract must be reviewed for backward compatibility impact.
