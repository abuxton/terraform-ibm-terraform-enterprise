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
