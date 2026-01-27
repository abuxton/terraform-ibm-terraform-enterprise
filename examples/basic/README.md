# Basic TFE Deployment Example

This example demonstrates a minimal single-instance Terraform Enterprise deployment on IBM Cloud in "external" operational mode.

## Architecture

- **Operational Mode**: External (single instance)
- **Deployment Size**: Medium (8 vCPU, 32GB RAM)
- **Network Connectivity**: Hybrid (private backend, public load balancer)
- **High Availability**: Single AZ (for dev/test environments)

## Prerequisites

1. IBM Cloud VPC with subnets across multiple zones
2. Secrets Manager instance with pre-created secrets:
   - TFE license file
   - TFE encryption password
   - Database admin password
   - TLS certificate and private key
3. Key Protect instance with encryption key
4. SSH key registered in IBM Cloud

See [../../docs/tfe-bootstrap-secrets.md](../../docs/tfe-bootstrap-secrets.md) for detailed setup instructions.

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Fill in your IBM Cloud resource values
3. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

4. After deployment completes (~30 minutes), access TFE at the URL shown in outputs
5. Complete initial admin user setup via the TFE web interface

## Outputs

- `tfe_url`: The HTTPS URL to access TFE
- `load_balancer_hostname`: Load balancer hostname (point your DNS here)
- `instance_group_id`: ID of the TFE instance group

## Next Steps

- Configure DNS to point `tfe_hostname` to `load_balancer_hostname`
- Access TFE and create initial admin account
- Configure VCS integration (GitHub, GitLab, etc.)
- Create your first workspace and run a Terraform plan

## Estimated Costs

Monthly cost estimate for this configuration (us-south region):
- VSI (1x bx2-8x32): ~$300/month
- PostgreSQL (4vCPU, 16GB): ~$250/month
- Object Storage: ~$10/month (variable based on usage)
- Load Balancer: ~$60/month
- **Total**: ~$620/month

## Cleanup

```bash
terraform destroy
```

**Note**: Database deletion takes ~15-20 minutes. Ensure you have backups before destroying.
