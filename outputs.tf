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
# Module Outputs
##############################################################################

#######################################
# TFE Application Outputs
#######################################

output "tfe_url" {
  description = "The HTTPS URL to access Terraform Enterprise"
  value       = "https://${var.tfe_hostname}"
}

output "tfe_hostname" {
  description = "The fully qualified domain name for TFE"
  value       = var.tfe_hostname
}

#######################################
# Load Balancer Outputs
#######################################

output "load_balancer_hostname" {
  description = "The hostname of the load balancer (point DNS to this)"
  value       = try(ibm_is_lb.tfe.hostname, null)
}

output "load_balancer_id" {
  description = "The ID of the load balancer"
  value       = try(ibm_is_lb.tfe.id, null)
}

output "load_balancer_public_ips" {
  description = "Public IPs of the load balancer (if public)"
  value       = try(ibm_is_lb.tfe.public_ips, [])
}

output "load_balancer_private_ips" {
  description = "Private IPs of the load balancer"
  value       = try(ibm_is_lb.tfe.private_ips, [])
}

#######################################
# Compute Outputs
#######################################

output "instance_group_id" {
  description = "The ID of the instance group managing TFE instances"
  value       = try(ibm_is_instance_group.tfe.id, null)
}

output "instance_ids" {
  description = "List of VSI instance IDs"
  value       = try(ibm_is_instance_group.tfe.instances, [])
}

#######################################
# Database Outputs
#######################################

output "database_id" {
  description = "The ID of the PostgreSQL database instance"
  value       = try(ibm_database.postgresql.id, null)
}

output "database_endpoint" {
  description = "The connection endpoint for the PostgreSQL database"
  value       = try(data.ibm_database_connection.postgresql.postgres[0].composed, null)
  sensitive   = true
}

output "database_port" {
  description = "The port number for PostgreSQL connections"
  value       = try(data.ibm_database_connection.postgresql.postgres[0].hosts[0].port, 5432)
}

output "database_name" {
  description = "The name of the TFE database"
  value       = try(ibm_database.postgresql.name, null)
}

#######################################
# Redis Outputs (Active-Active Mode)
#######################################

output "redis_id" {
  description = "The ID of the Redis instance (null if external mode)"
  value       = try(ibm_database.redis[0].id, null)
}

output "redis_endpoint" {
  description = "The connection endpoint for Redis (null if external mode)"
  value       = try(data.ibm_database_connection.redis[0].rediss[0].composed, null)
  sensitive   = true
}

output "redis_port" {
  description = "The port number for Redis connections"
  value       = try(data.ibm_database_connection.redis[0].rediss[0].hosts[0].port, 6379)
}

#######################################
# Object Storage Outputs
#######################################

output "cos_bucket_name" {
  description = "The name of the Object Storage bucket"
  value       = var.cos_bucket_name
}

output "cos_bucket_id" {
  description = "The ID of the Object Storage bucket"
  value       = try(ibm_cos_bucket.tfe.id, null)
}

output "cos_bucket_crn" {
  description = "The CRN of the Object Storage bucket"
  value       = try(ibm_cos_bucket.tfe.crn, null)
}

#######################################
# Security Outputs
#######################################

output "compute_security_group_id" {
  description = "The ID of the compute security group"
  value       = try(ibm_is_security_group.compute.id, null)
}

output "load_balancer_security_group_id" {
  description = "The ID of the load balancer security group"
  value       = try(ibm_is_security_group.load_balancer.id, null)
}

output "database_security_group_id" {
  description = "The ID of the database security group"
  value       = try(ibm_is_security_group.database.id, null)
}
