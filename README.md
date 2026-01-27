# Terraform Enterprise on IBM Cloud (HVD)

This Terraform module deploys Terraform Enterprise (TFE) on IBM Cloud VPC infrastructure following HashiCorp Validated Design (HVD) patterns adapted from the AWS reference architecture.

## Features

- **Flexible Operational Modes**: Deploy in single-instance "external" mode or high-availability "active-active" mode with Redis
- **Preset Sizing**: Choose from small/medium/large presets or customize instance profiles and database sizing
- **Network Flexibility**: Support for public, hybrid, or fully private network connectivity
- **Enhanced Security**: All secrets managed via IBM Cloud Secrets Manager, encryption at rest with Key Protect, TLS 1.2+
- **Observability Ready**: Optional integration with IBM Log Analysis and IBM Cloud Monitoring
- **Air-Gapped Support**: Deploy in restricted environments with custom container registries and HTTP proxies

## Architecture

The module deploys the following IBM Cloud resources:

- **Compute**: Virtual Server Instances (VSI) with instance groups for autoscaling
- **Database**: IBM Cloud Databases for PostgreSQL (14+) for TFE application data
- **Caching**: IBM Cloud Databases for Redis (active-active mode only) for distributed locking
- **Storage**: IBM Cloud Object Storage (COS) for TFE artifacts and state files
- **Networking**: Load Balancer (NLB), Security Groups, optional DNS records
- **Security**: Secrets Manager integration, Key Protect encryption, IAM policies

## Prerequisites

Before deploying this module, you must have:

1. **IBM Cloud Account** with appropriate permissions
2. **VPC Infrastructure** (VPC, subnets across multiple zones)
3. **Secrets Manager Instance** with pre-created secrets:
   - TFE license file
   - TFE encryption password
   - Database admin password
   - TLS certificate and private key
   - Redis password (if using active-active mode)
4. **Key Protect Instance** with encryption key for data at rest
5. **SSH Key** registered in IBM Cloud for VSI access
6. **TLS Certificate** matching your TFE hostname (e.g., `tfe.example.com`)

See [docs/tfe-bootstrap-secrets.md](docs/tfe-bootstrap-secrets.md) for detailed secret setup instructions.

## Usage

### Basic Single-Instance Deployment

```hcl
module "tfe" {
  source = "terraform-ibm-modules/terraform-enterprise/ibm"

  # Core Configuration
  resource_group_id     = "your-resource-group-id"
  region                = "us-south"
  vpc_id                = "your-vpc-id"
  friendly_name_prefix  = "prod"

  # Deployment Configuration
  tfe_operational_mode  = "external"
  deployment_size       = "medium"
  network_connectivity  = "hybrid"
  tfe_hostname          = "tfe.example.com"

  # Compute Configuration
  subnet_ids            = ["subnet-id-zone-1", "subnet-id-zone-2"]
  ssh_key_ids           = ["your-ssh-key-name"]

  # Load Balancer Configuration
  lb_subnet_ids         = ["lb-subnet-id-zone-1", "lb-subnet-id-zone-2"]
  tls_certificate_crn   = "crn:v1:bluemix:public:secrets-manager:us-south:..."
  allowed_ingress_cidrs = ["10.0.0.0/8"]

  # Storage Configuration
  cos_bucket_name       = "tfe-artifacts-prod"
  kms_key_crn           = "crn:v1:bluemix:public:kms:us-south:..."

  # Secrets Configuration
  secrets_manager_instance_crn     = "crn:v1:bluemix:public:secrets-manager:us-south:..."
  tfe_license_secret_crn           = "crn:v1:bluemix:public:secrets-manager:us-south:.../secret-id-1"
  tfe_encryption_password_secret_crn = "crn:v1:bluemix:public:secrets-manager:us-south:.../secret-id-2"
  database_password_secret_crn     = "crn:v1:bluemix:public:secrets-manager:us-south:.../secret-id-3"
}
```

### High Availability Active-Active Deployment

```hcl
module "tfe" {
  source = "terraform-ibm-modules/terraform-enterprise/ibm"

  # ... (same basic configuration as above) ...

  # Active-Active Configuration
  tfe_operational_mode       = "active-active"
  instance_count             = 3
  redis_password_secret_crn  = "crn:v1:bluemix:public:secrets-manager:us-south:.../secret-id-4"
}
```

See [examples/](examples/) directory for complete working examples:
- [examples/basic/](examples/basic/) - Minimal single-instance deployment
- [examples/active-active/](examples/active-active/) - High availability deployment
- [examples/air-gapped/](examples/air-gapped/) - Air-gapped/private deployment

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| ibm | >= 1.70.0 |

## Documentation

- [Deployment Customizations](docs/deployment-customizations.md)
- [TFE Version Upgrades](docs/tfe-version-upgrades.md)
- [TLS Certificate Rotation](docs/tfe-cert-rotation.md)
- [Secrets Bootstrap Guide](docs/tfe-bootstrap-secrets.md)
- [Troubleshooting](docs/troubleshooting.md)

## Testing

This module includes native Terraform tests (.tftest.hcl files):

```bash
terraform init
terraform test
```

See [tests/](tests/) directory for test configurations.

## Support

For issues and feature requests, please use the GitHub issue tracker.

## License

Licensed under the Apache License, Version 2.0. See LICENSE for details.

## Module Authorship

This module is maintained by IBM and follows HashiCorp Validated Design patterns.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.70.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | >= 1.70.0 |

## Resources

| Name | Type |
|------|------|
| [ibm_cos_bucket.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cos_bucket) | resource |
| [ibm_database.postgresql](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database) | resource |
| [ibm_database.redis](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database) | resource |
| [ibm_iam_authorization_policy.cos_to_kms](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_authorization_policy) | resource |
| [ibm_iam_authorization_policy.database_to_kms](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_authorization_policy) | resource |
| [ibm_iam_authorization_policy.redis_to_kms](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_authorization_policy) | resource |
| [ibm_iam_authorization_policy.vsi_to_cos](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_authorization_policy) | resource |
| [ibm_iam_authorization_policy.vsi_to_secrets_manager](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_authorization_policy) | resource |
| [ibm_iam_service_api_key.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_service_api_key) | resource |
| [ibm_iam_service_id.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_service_id) | resource |
| [ibm_iam_service_policy.tfe_cos_access](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_service_policy) | resource |
| [ibm_iam_service_policy.tfe_secrets_access](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_service_policy) | resource |
| [ibm_is_instance_group.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_instance_group) | resource |
| [ibm_is_instance_group_manager.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_instance_group_manager) | resource |
| [ibm_is_instance_group_manager_policy.cpu](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_instance_group_manager_policy) | resource |
| [ibm_is_instance_template.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_instance_template) | resource |
| [ibm_is_lb.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb) | resource |
| [ibm_is_lb_listener.tfe_http_redirect](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb_listener) | resource |
| [ibm_is_lb_listener.tfe_https](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb_listener) | resource |
| [ibm_is_lb_pool.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb_pool) | resource |
| [ibm_is_security_group.compute](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group) | resource |
| [ibm_is_security_group.database](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group) | resource |
| [ibm_is_security_group.load_balancer](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group) | resource |
| [ibm_is_security_group_rule.compute_egress_all](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.compute_ingress_http](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.compute_ingress_https](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.compute_ingress_ssh](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.db_ingress_postgres](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.db_ingress_redis](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.lb_egress_compute](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_is_security_group_rule.lb_ingress_https](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_database_connection.postgresql](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/database_connection) | data source |
| [ibm_database_connection.redis](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/database_connection) | data source |
| [ibm_is_images.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_images) | data source |
| [ibm_is_ssh_key.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_subnet.compute](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_subnet) | data source |
| [ibm_is_subnet.lb](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_subnet) | data source |
| [ibm_is_vpc.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_vpc) | data source |
| [ibm_is_zones.regional](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_zones) | data source |
| [ibm_resource_group.cos](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/resource_group) | data source |
| [ibm_resource_group.tfe](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cos_bucket_name"></a> [cos\_bucket\_name](#input\_cos\_bucket\_name) | Name of the Object Storage bucket for TFE artifacts and state files | `string` | n/a | yes |
| <a name="input_database_password_secret_crn"></a> [database\_password\_secret\_crn](#input\_database\_password\_secret\_crn) | CRN of the database admin password secret in Secrets Manager | `string` | n/a | yes |
| <a name="input_kms_key_crn"></a> [kms\_key\_crn](#input\_kms\_key\_crn) | CRN of the Key Protect or HPCS key for encryption at rest | `string` | n/a | yes |
| <a name="input_lb_subnet_ids"></a> [lb\_subnet\_ids](#input\_lb\_subnet\_ids) | List of subnet IDs for load balancer (must span multiple availability zones) | `list(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | IBM Cloud region where resources will be deployed (e.g., 'us-south', 'eu-de') | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | ID of the IBM Cloud resource group where resources will be created | `string` | n/a | yes |
| <a name="input_secrets_manager_instance_crn"></a> [secrets\_manager\_instance\_crn](#input\_secrets\_manager\_instance\_crn) | CRN of the Secrets Manager instance containing all secrets | `string` | n/a | yes |
| <a name="input_ssh_key_ids"></a> [ssh\_key\_ids](#input\_ssh\_key\_ids) | List of SSH key names for VSI access | `list(string)` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs for TFE compute instances (must span multiple availability zones for HA) | `list(string)` | n/a | yes |
| <a name="input_tfe_encryption_password_secret_crn"></a> [tfe\_encryption\_password\_secret\_crn](#input\_tfe\_encryption\_password\_secret\_crn) | CRN of the TFE encryption password secret in Secrets Manager (for securing sensitive data at rest) | `string` | n/a | yes |
| <a name="input_tfe_hostname"></a> [tfe\_hostname](#input\_tfe\_hostname) | Fully qualified domain name for TFE (e.g., 'tfe.example.com'). Must match TLS certificate. | `string` | n/a | yes |
| <a name="input_tfe_license_secret_crn"></a> [tfe\_license\_secret\_crn](#input\_tfe\_license\_secret\_crn) | CRN of the TFE license file secret in Secrets Manager | `string` | n/a | yes |
| <a name="input_tls_certificate_crn"></a> [tls\_certificate\_crn](#input\_tls\_certificate\_crn) | CRN of the TLS certificate in Secrets Manager for HTTPS listener | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where TFE will be deployed | `string` | n/a | yes |
| <a name="input_activity_tracker_crn"></a> [activity\_tracker\_crn](#input\_activity\_tracker\_crn) | CRN of the Activity Tracker instance for audit logging (optional) | `string` | `null` | no |
| <a name="input_allowed_ingress_cidrs"></a> [allowed\_ingress\_cidrs](#input\_allowed\_ingress\_cidrs) | List of CIDR blocks allowed to access TFE (e.g., ['10.0.0.0/8', '172.16.0.0/12']) | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | Maximum number of instances in autoscaling group (active-active mode only) | `number` | `5` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | Minimum number of instances in autoscaling group (active-active mode only) | `number` | `2` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | List of tags to apply to all resources for cost allocation and organization | `list(string)` | `[]` | no |
| <a name="input_cos_storage_class"></a> [cos\_storage\_class](#input\_cos\_storage\_class) | Storage class for the COS bucket (standard, vault, cold, flex) | `string` | `"standard"` | no |
| <a name="input_database_backup_retention_days"></a> [database\_backup\_retention\_days](#input\_database\_backup\_retention\_days) | Number of days to retain database backups | `number` | `7` | no |
| <a name="input_database_cpu"></a> [database\_cpu](#input\_database\_cpu) | Database CPU allocation (only used when deployment\_size = 'custom') | `number` | `4` | no |
| <a name="input_database_memory"></a> [database\_memory](#input\_database\_memory) | Database memory allocation in MB (only used when deployment\_size = 'custom') | `number` | `16384` | no |
| <a name="input_database_version"></a> [database\_version](#input\_database\_version) | PostgreSQL version (14 or higher required by TFE) | `string` | `"14"` | no |
| <a name="input_deployment_size"></a> [deployment\_size](#input\_deployment\_size) | Preset deployment size: 'small', 'medium', 'large', or 'custom'. Determines instance profiles and database sizing. | `string` | `"medium"` | no |
| <a name="input_enable_log_forwarding"></a> [enable\_log\_forwarding](#input\_enable\_log\_forwarding) | Enable log forwarding to IBM Log Analysis or COS | `bool` | `false` | no |
| <a name="input_friendly_name_prefix"></a> [friendly\_name\_prefix](#input\_friendly\_name\_prefix) | Prefix for resource names (lowercase, alphanumeric, hyphens only) | `string` | `null` | no |
| <a name="input_image_id"></a> [image\_id](#input\_image\_id) | ID of the VSI base image (Ubuntu 22.04 LTS / RHEL 8+ / Rocky Linux 8+ recommended) | `string` | `null` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Number of TFE instances (must be 1 for 'external' mode, >= 2 for 'active-active' mode) | `number` | `1` | no |
| <a name="input_instance_profile"></a> [instance\_profile](#input\_instance\_profile) | VSI instance profile (only used when deployment\_size = 'custom'). Must meet TFE minimum: 4 vCPU, 16GB RAM. | `string` | `"bx2-8x32"` | no |
| <a name="input_log_forwarding_destination"></a> [log\_forwarding\_destination](#input\_log\_forwarding\_destination) | Log forwarding destination: 'logdna', 'cos', or 'custom' | `string` | `"logdna"` | no |
| <a name="input_logdna_ingestion_key_secret_crn"></a> [logdna\_ingestion\_key\_secret\_crn](#input\_logdna\_ingestion\_key\_secret\_crn) | CRN of the LogDNA ingestion key secret in Secrets Manager (required if log\_forwarding\_destination = 'logdna') | `string` | `null` | no |
| <a name="input_network_connectivity"></a> [network\_connectivity](#input\_network\_connectivity) | Network connectivity mode: 'public' (internet-facing), 'hybrid' (private backend, public LB), or 'private' (fully private) | `string` | `"hybrid"` | no |
| <a name="input_redis_memory_mb"></a> [redis\_memory\_mb](#input\_redis\_memory\_mb) | Redis memory allocation in MB (only used when deployment\_size = 'custom' and tfe\_operational\_mode = 'active-active') | `number` | `12288` | no |
| <a name="input_redis_password_secret_crn"></a> [redis\_password\_secret\_crn](#input\_redis\_password\_secret\_crn) | CRN of the Redis password secret in Secrets Manager (required for active-active mode) | `string` | `null` | no |
| <a name="input_tfe_image_repository"></a> [tfe\_image\_repository](#input\_tfe\_image\_repository) | Container registry URL for TFE image (default: HashiCorp registry) | `string` | `"images.releases.hashicorp.com/hashicorp/terraform-enterprise"` | no |
| <a name="input_tfe_image_tag"></a> [tfe\_image\_tag](#input\_tfe\_image\_tag) | TFE container image tag/version (e.g., 'v202401-1') | `string` | `"latest"` | no |
| <a name="input_tfe_operational_mode"></a> [tfe\_operational\_mode](#input\_tfe\_operational\_mode) | TFE operational mode: 'external' (single instance) or 'active-active' (multi-instance with Redis) | `string` | `"external"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_security_group_id"></a> [compute\_security\_group\_id](#output\_compute\_security\_group\_id) | The ID of the compute security group |
| <a name="output_cos_bucket_crn"></a> [cos\_bucket\_crn](#output\_cos\_bucket\_crn) | The CRN of the Object Storage bucket |
| <a name="output_cos_bucket_id"></a> [cos\_bucket\_id](#output\_cos\_bucket\_id) | The ID of the Object Storage bucket |
| <a name="output_cos_bucket_name"></a> [cos\_bucket\_name](#output\_cos\_bucket\_name) | The name of the Object Storage bucket |
| <a name="output_database_endpoint"></a> [database\_endpoint](#output\_database\_endpoint) | The connection endpoint for the PostgreSQL database |
| <a name="output_database_id"></a> [database\_id](#output\_database\_id) | The ID of the PostgreSQL database instance |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | The name of the TFE database |
| <a name="output_database_port"></a> [database\_port](#output\_database\_port) | The port number for PostgreSQL connections |
| <a name="output_database_security_group_id"></a> [database\_security\_group\_id](#output\_database\_security\_group\_id) | The ID of the database security group |
| <a name="output_instance_group_id"></a> [instance\_group\_id](#output\_instance\_group\_id) | The ID of the instance group managing TFE instances |
| <a name="output_instance_ids"></a> [instance\_ids](#output\_instance\_ids) | List of VSI instance IDs |
| <a name="output_load_balancer_hostname"></a> [load\_balancer\_hostname](#output\_load\_balancer\_hostname) | The hostname of the load balancer (point DNS to this) |
| <a name="output_load_balancer_id"></a> [load\_balancer\_id](#output\_load\_balancer\_id) | The ID of the load balancer |
| <a name="output_load_balancer_private_ips"></a> [load\_balancer\_private\_ips](#output\_load\_balancer\_private\_ips) | Private IPs of the load balancer |
| <a name="output_load_balancer_public_ips"></a> [load\_balancer\_public\_ips](#output\_load\_balancer\_public\_ips) | Public IPs of the load balancer (if public) |
| <a name="output_load_balancer_security_group_id"></a> [load\_balancer\_security\_group\_id](#output\_load\_balancer\_security\_group\_id) | The ID of the load balancer security group |
| <a name="output_redis_endpoint"></a> [redis\_endpoint](#output\_redis\_endpoint) | The connection endpoint for Redis (null if external mode) |
| <a name="output_redis_id"></a> [redis\_id](#output\_redis\_id) | The ID of the Redis instance (null if external mode) |
| <a name="output_redis_port"></a> [redis\_port](#output\_redis\_port) | The port number for Redis connections |
| <a name="output_tfe_hostname"></a> [tfe\_hostname](#output\_tfe\_hostname) | The fully qualified domain name for TFE |
| <a name="output_tfe_url"></a> [tfe\_url](#output\_tfe\_url) | The HTTPS URL to access Terraform Enterprise |
<!-- END_TF_DOCS -->