/**
 * Copyright 2024 IBM Corp.
 */

variable "resource_group_id" {
  description = "ID of the IBM Cloud resource group"
  type        = string
}

variable "region" {
  description = "IBM Cloud region (e.g., 'us-south')"
  type        = string
  default     = "us-south"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "friendly_name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "tfe-basic"
}

variable "tfe_hostname" {
  description = "FQDN for TFE (e.g., 'tfe.example.com')"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for compute instances"
  type        = list(string)
}

variable "ssh_key_ids" {
  description = "List of SSH key names"
  type        = list(string)
}

variable "lb_subnet_ids" {
  description = "List of subnet IDs for load balancer"
  type        = list(string)
}

variable "tls_certificate_crn" {
  description = "CRN of TLS certificate in Secrets Manager"
  type        = string
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to access TFE"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cos_bucket_name" {
  description = "Name of Object Storage bucket"
  type        = string
}

variable "kms_key_crn" {
  description = "CRN of Key Protect encryption key"
  type        = string
}

variable "secrets_manager_instance_crn" {
  description = "CRN of Secrets Manager instance"
  type        = string
}

variable "tfe_license_secret_crn" {
  description = "CRN of TFE license secret"
  type        = string
}

variable "tfe_encryption_password_secret_crn" {
  description = "CRN of TFE encryption password secret"
  type        = string
}

variable "database_password_secret_crn" {
  description = "CRN of database password secret"
  type        = string
}

variable "common_tags" {
  description = "List of tags for resources"
  type        = list(string)
  default     = []
}
