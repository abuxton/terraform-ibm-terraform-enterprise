/**
 * Copyright 2024 IBM Corp.
 *
 * Basic TFE Deployment Example
 * 
 * This example demonstrates a minimal single-instance TFE deployment
 * in "external" operational mode.
 */

module "tfe" {
  source = "../.."

  # Core Configuration
  resource_group_id    = var.resource_group_id
  region               = var.region
  vpc_id               = var.vpc_id
  friendly_name_prefix = var.friendly_name_prefix

  # Deployment Configuration
  tfe_operational_mode = "external"
  deployment_size      = "medium"
  network_connectivity = "hybrid"
  tfe_hostname         = var.tfe_hostname

  # Compute Configuration
  subnet_ids  = var.subnet_ids
  ssh_key_ids = var.ssh_key_ids

  # Load Balancer Configuration
  lb_subnet_ids         = var.lb_subnet_ids
  tls_certificate_crn   = var.tls_certificate_crn
  allowed_ingress_cidrs = var.allowed_ingress_cidrs

  # Storage Configuration
  cos_bucket_name = var.cos_bucket_name
  kms_key_crn     = var.kms_key_crn

  # Secrets Configuration
  secrets_manager_instance_crn       = var.secrets_manager_instance_crn
  tfe_license_secret_crn             = var.tfe_license_secret_crn
  tfe_encryption_password_secret_crn = var.tfe_encryption_password_secret_crn
  database_password_secret_crn       = var.database_password_secret_crn

  # Tags
  common_tags = var.common_tags
}
