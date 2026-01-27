/**
 * Copyright 2024 IBM Corp.
 */

output "tfe_url" {
  description = "The HTTPS URL to access TFE"
  value       = module.tfe.tfe_url
}

output "load_balancer_hostname" {
  description = "Load balancer hostname for DNS configuration"
  value       = module.tfe.load_balancer_hostname
}

output "instance_group_id" {
  description = "ID of the TFE instance group"
  value       = module.tfe.instance_group_id
}
