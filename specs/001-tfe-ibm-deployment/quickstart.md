# Quickstart Guide: Deploy Terraform Enterprise on IBM Cloud

**Feature**: Terraform Enterprise on IBM Cloud (HVD)  
**Audience**: Infrastructure engineers deploying TFE for the first time  
**Time to Complete**: ~45 minutes (30 min deployment + 15 min setup)

## Overview

This guide walks through deploying a functional single-instance Terraform Enterprise installation on IBM Cloud in under an hour. You'll provision compute, database, storage, and networking resources, then access TFE via HTTPS to create the initial admin user.

**What You'll Deploy**:
- 1 VSI running TFE container (bx2-8x32: 8 vCPU, 32GB RAM)
- PostgreSQL database (4 vCPU, 16GB RAM, HA configuration)
- Object Storage bucket for artifacts
- Network Load Balancer for HTTPS access
- Security groups with least-privilege firewall rules

**Prerequisites Checklist**:
- [ ] IBM Cloud account with appropriate permissions
- [ ] IBM Cloud CLI installed and authenticated
- [ ] Terraform CLI 1.9.0+ installed
- [ ] TFE license file (`.hclic` format)
- [ ] Valid TLS certificate and private key
- [ ] Existing VPC with subnets across multiple zones

---

## Step 1: Prepare IBM Cloud Environment (15 minutes)

### 1.1 Create VPC and Subnets

If you don't have an existing VPC, create one:

```bash
# Set region
export IBM_CLOUD_REGION="us-south"

# Create VPC
ibmcloud is vpc-create tfe-vpc --resource-group-name default

# Get VPC ID
VPC_ID=$(ibmcloud is vpcs --output json | jq -r '.[] | select(.name=="tfe-vpc") | .id')

# Create compute subnets (3 zones for HA)
ibmcloud is subnet-create tfe-compute-zone1 $VPC_ID --zone us-south-1 --ipv4-cidr-block 10.240.0.0/24
ibmcloud is subnet-create tfe-compute-zone2 $VPC_ID --zone us-south-2 --ipv4-cidr-block 10.240.1.0/24
ibmcloud is subnet-create tfe-compute-zone3 $VPC_ID --zone us-south-3 --ipv4-cidr-block 10.240.2.0/24

# Create load balancer subnets (3 zones)
ibmcloud is subnet-create tfe-lb-zone1 $VPC_ID --zone us-south-1 --ipv4-cidr-block 10.240.10.0/24
ibmcloud is subnet-create tfe-lb-zone2 $VPC_ID --zone us-south-2 --ipv4-cidr-block 10.240.11.0/24
ibmcloud is subnet-create tfe-lb-zone3 $VPC_ID --zone us-south-3 --ipv4-cidr-block 10.240.12.0/24

# Get subnet IDs
COMPUTE_SUBNET_IDS=$(ibmcloud is subnets --output json | jq -r '[.[] | select(.name | startswith("tfe-compute")) | .id] | join(",")')
LB_SUBNET_IDS=$(ibmcloud is subnets --output json | jq -r '[.[] | select(.name | startswith("tfe-lb")) | .id] | join(",")')
```

### 1.2 Create SSH Key (Optional, for debugging)

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/tfe-key -N ""

# Upload public key to IBM Cloud
ibmcloud is key-create tfe-ssh-key @~/.ssh/tfe-key.pub

# Get key ID
SSH_KEY_ID=$(ibmcloud is keys --output json | jq -r '.[] | select(.name=="tfe-ssh-key") | .id')
```

### 1.3 Create Secrets Manager Instance

```bash
# Create Secrets Manager instance
ibmcloud resource service-instance-create tfe-secrets secrets-manager standard $IBM_CLOUD_REGION

# Get instance ID
SECRETS_MANAGER_ID=$(ibmcloud resource service-instance tfe-secrets --output json | jq -r '.[] | .guid')
```

### 1.4 Create Key Protect Instance and Root Key

```bash
# Create Key Protect instance
ibmcloud resource service-instance-create tfe-keyprotect kms tiered-pricing $IBM_CLOUD_REGION

# Get instance ID
KMS_INSTANCE_ID=$(ibmcloud resource service-instance tfe-keyprotect --output json | jq -r '.[] | .guid')

# Create root key for encryption
ibmcloud kp key create tfe-encryption-key --instance-id $KMS_INSTANCE_ID

# Get key CRN
KMS_KEY_CRN=$(ibmcloud kp key list --instance-id $KMS_INSTANCE_ID --output json | jq -r '.[0].crn')
```

---

## Step 2: Prepare Secrets (10 minutes)

### 2.1 Create Required Secrets in Secrets Manager

```bash
# Set Secrets Manager instance ID
export SECRETS_MANAGER_INSTANCE_ID=$SECRETS_MANAGER_ID

# 1. TFE License (base64-encoded)
LICENSE_B64=$(base64 -i /path/to/terraform.hclic)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-license" \
  --description "TFE production license" \
  --payload "$LICENSE_B64"

# Get license secret CRN
LICENSE_CRN=$(ibmcloud secrets-manager secrets --output json | jq -r '.secrets[] | select(.name=="tfe-license") | .crn')

# 2. TLS Certificate (full chain)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-tls-certificate" \
  --payload "$(cat /path/to/fullchain.pem)"

CERT_CRN=$(ibmcloud secrets-manager secrets --output json | jq -r '.secrets[] | select(.name=="tfe-tls-certificate") | .crn')

# 3. TLS Private Key (no passphrase)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-tls-private-key" \
  --payload "$(cat /path/to/privkey.pem)"

KEY_CRN=$(ibmcloud secrets-manager secrets --output json | jq -r '.secrets[] | select(.name=="tfe-tls-private-key") | .crn')

# 4. TFE Encryption Password (32 characters)
ENCRYPTION_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-encryption-password" \
  --payload "$ENCRYPTION_PASSWORD"

ENC_PASS_CRN=$(ibmcloud secrets-manager secrets --output json | jq -r '.secrets[] | select(.name=="tfe-encryption-password") | .crn')

# 5. Database Password (24 characters)
DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | head -c 24)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-database-password" \
  --payload "$DB_PASSWORD"

DB_PASS_CRN=$(ibmcloud secrets-manager secrets --output json | jq -r '.secrets[] | select(.name=="tfe-database-password") | .crn')

# Save CRNs for later use
cat > tfe-secrets.env <<EOF
export LICENSE_CRN=$LICENSE_CRN
export CERT_CRN=$CERT_CRN
export KEY_CRN=$KEY_CRN
export ENC_PASS_CRN=$ENC_PASS_CRN
export DB_PASS_CRN=$DB_PASS_CRN
EOF

echo "✅ Secrets created. Source tfe-secrets.env to use these values."
```

**Security Note**: Store `tfe-secrets.env` securely (contains sensitive CRNs).

---

## Step 3: Deploy TFE Module (30 minutes)

### 3.1 Create Terraform Configuration

```bash
mkdir tfe-deployment && cd tfe-deployment
```

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.9.0"
  
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.70"
    }
  }
}

provider "ibm" {
  region = var.region
}

module "tfe" {
  source  = "terraform-ibm-modules/terraform-enterprise/ibm"
  version = "~> 1.0"
  
  # Core Configuration
  friendly_name_prefix = var.friendly_name_prefix
  region               = var.region
  resource_group_id    = var.resource_group_id
  tfe_hostname         = var.tfe_hostname
  
  # Networking
  vpc_id                     = var.vpc_id
  compute_subnet_ids         = var.compute_subnet_ids
  lb_subnet_ids              = var.lb_subnet_ids
  ingress_cidr_blocks_https  = var.ingress_cidr_blocks_https
  
  # Secrets
  secrets_manager_instance_id       = var.secrets_manager_instance_id
  tfe_license_secret_crn            = var.tfe_license_secret_crn
  tls_certificate_secret_crn        = var.tls_certificate_secret_crn
  tls_private_key_secret_crn        = var.tls_private_key_secret_crn
  tfe_encryption_password_secret_crn = var.tfe_encryption_password_secret_crn
  database_admin_password_secret_crn = var.database_admin_password_secret_crn
  
  # Encryption
  kms_key_crn = var.kms_key_crn
  
  # Deployment Configuration
  tfe_operational_mode = "external"  # Single instance
  deployment_size      = "medium"    # 8 vCPU, 32GB RAM
  
  # Tagging
  common_tags = [
    "environment:production",
    "application:terraform-enterprise",
    "managed-by:terraform"
  ]
}

output "tfe_url" {
  description = "TFE application URL"
  value       = module.tfe.tfe_url
}

output "tfe_admin_url" {
  description = "Initial admin setup URL"
  value       = module.tfe.tfe_admin_url
}

output "load_balancer_hostname" {
  description = "Load balancer DNS hostname (update your DNS to point here)"
  value       = module.tfe.load_balancer_hostname
}
```

Create `variables.tf`:

```hcl
variable "friendly_name_prefix" {
  type        = string
  description = "Resource naming prefix"
  default     = "prod-tfe"
}

variable "region" {
  type        = string
  description = "IBM Cloud region"
  default     = "us-south"
}

variable "resource_group_id" {
  type        = string
  description = "Resource group ID"
}

variable "tfe_hostname" {
  type        = string
  description = "TFE FQDN (e.g., tfe.example.com)"
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID"
}

variable "compute_subnet_ids" {
  type        = list(string)
  description = "Compute subnet IDs"
}

variable "lb_subnet_ids" {
  type        = list(string)
  description = "Load balancer subnet IDs"
}

variable "ingress_cidr_blocks_https" {
  type        = list(string)
  description = "Allowed CIDR blocks for HTTPS access"
  default     = ["0.0.0.0/0"]  # Public access (restrict in production)
}

variable "secrets_manager_instance_id" {
  type        = string
  description = "Secrets Manager instance ID"
}

variable "tfe_license_secret_crn" {
  type = string
}

variable "tls_certificate_secret_crn" {
  type = string
}

variable "tls_private_key_secret_crn" {
  type = string
}

variable "tfe_encryption_password_secret_crn" {
  type = string
}

variable "database_admin_password_secret_crn" {
  type = string
}

variable "kms_key_crn" {
  type        = string
  description = "Key Protect encryption key CRN"
}
```

Create `terraform.tfvars`:

```hcl
# Source the secrets env file first: source ../tfe-secrets.env

region               = "us-south"
resource_group_id    = "<YOUR_RESOURCE_GROUP_ID>"
tfe_hostname         = "tfe.example.com"  # Change to your domain
vpc_id               = "<YOUR_VPC_ID>"
compute_subnet_ids   = ["<SUBNET_1>", "<SUBNET_2>", "<SUBNET_3>"]
lb_subnet_ids        = ["<LB_SUBNET_1>", "<LB_SUBNET_2>", "<LB_SUBNET_3>"]

# From tfe-secrets.env
secrets_manager_instance_id       = "<SECRETS_MANAGER_ID>"
tfe_license_secret_crn            = "<FROM_LICENSE_CRN>"
tls_certificate_secret_crn        = "<FROM_CERT_CRN>"
tls_private_key_secret_crn        = "<FROM_KEY_CRN>"
tfe_encryption_password_secret_crn = "<FROM_ENC_PASS_CRN>"
database_admin_password_secret_crn = "<FROM_DB_PASS_CRN>"
kms_key_crn                       = "<FROM_KMS_KEY_CRN>"
```

### 3.2 Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy (takes ~30 minutes)
terraform apply

# Output example:
# tfe_url = "https://tfe.example.com"
# tfe_admin_url = "https://tfe.example.com/admin/account/new"
# load_balancer_hostname = "r006-abc123-456def.lb.appdomain.cloud"
```

**Provisioning Timeline**:
```
0:00  - Terraform begins deployment
0:01  - Security groups created
0:02  - Object Storage bucket created
0:05  - Load balancer provisioning starts
0:10  - Database provisioning starts (slowest component)
0:15  - Load balancer ready
0:25  - Database ready
0:27  - VSI instances launch
0:30  - TFE containers starting
0:35  - Health checks pass, deployment complete
```

---

## Step 4: Configure DNS (2 minutes)

### 4.1 Point DNS to Load Balancer

```bash
# Get load balancer hostname from Terraform output
LB_HOSTNAME=$(terraform output -raw load_balancer_hostname)

# Create DNS CNAME record (example for IBM Cloud DNS)
ibmcloud dns resource-record-create <DNS_ZONE_ID> \
  --type CNAME \
  --name tfe \
  --data $LB_HOSTNAME
```

**OR manually**:
- Log into your DNS provider
- Create CNAME record: `tfe.example.com` → `r006-abc123-456def.lb.appdomain.cloud`
- Wait for DNS propagation (1-5 minutes)

### 4.2 Verify DNS Resolution

```bash
# Check DNS propagation
nslookup tfe.example.com

# Test TLS certificate
openssl s_client -connect tfe.example.com:443 -servername tfe.example.com

# Expected: Certificate should show CN=tfe.example.com
```

---

## Step 5: Access TFE and Create Admin User (5 minutes)

### 5.1 Verify TFE Health

```bash
# Check health endpoint
curl -k https://tfe.example.com/_health_check

# Expected response:
# {"status":"ok","database":"ok","redis":"ok"}  # or just database for external mode
```

### 5.2 Create Initial Admin Account

1. Navigate to admin setup URL:
   ```bash
   terraform output tfe_admin_url
   # Open: https://tfe.example.com/admin/account/new
   ```

2. Fill in admin account details:
   - Username: `admin` (or your choice)
   - Email: `admin@example.com`
   - Password: Strong password (16+ characters)

3. Click **Create an account**

4. You'll be logged in to TFE dashboard

### 5.3 Create Test Workspace

1. Click **+ New Workspace**
2. Choose **CLI-driven workflow**
3. Name: `test-workspace`
4. Click **Create workspace**

5. Configure workspace settings (optional):
   - Terraform version
   - Environment variables
   - VCS connection (if applicable)

### 5.4 Run Test Terraform Plan

Create a simple test configuration:

```hcl
# test.tf
terraform {
  cloud {
    organization = "<YOUR_ORG_NAME>"
    workspaces {
      name = "test-workspace"
    }
  }
}

resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo 'TFE is working!'"
  }
}
```

Run Terraform:

```bash
terraform init
terraform plan
terraform apply

# Expected: Plan executes on TFE, outputs visible in UI
```

---

## Step 6: Production Hardening (Optional, 10 minutes)

### 6.1 Restrict HTTPS Access

Update `terraform.tfvars`:

```hcl
ingress_cidr_blocks_https = [
  "10.0.0.0/8",      # Corporate network
  "203.0.113.0/24"   # Office public IP
]
```

```bash
terraform apply
```

### 6.2 Enable Observability

```hcl
# Add to main.tf module block
enable_log_forwarding     = true
log_forwarding_destination = "logdna"
logdna_instance_crn       = "<YOUR_LOGDNA_CRN>"

enable_monitoring         = true
monitoring_instance_crn   = "<YOUR_SYSDIG_CRN>"
```

```bash
terraform apply
```

### 6.3 Configure Backup Policy

```bash
# Verify database backup configuration
ibmcloud cdb deployment-backups <DATABASE_ID>

# Output shows automated backups enabled with 35-day retention
```

---

## Troubleshooting

### Issue: VSI instances unhealthy in load balancer

**Symptoms**: Load balancer shows 0/1 healthy instances  
**Check**:
```bash
# View VSI console logs
ibmcloud is instance-console <INSTANCE_ID>

# Common issues:
# - Secret retrieval failure (check IAM policy)
# - TFE container failed to start (check license validity)
# - Database connection failure (check security group rules)
```

### Issue: Cannot access TFE URL

**Symptoms**: Browser shows "connection refused" or timeout  
**Check**:
```bash
# Verify DNS
nslookup tfe.example.com

# Test load balancer directly
curl -k https://<LB_HOSTNAME>/_health_check

# Check security group rules
ibmcloud is security-group <LB_SG_ID>
# Ensure rule allows 0.0.0.0/0 (or your IP) on port 443
```

### Issue: TFE shows license error

**Symptoms**: TFE logs show "invalid license"  
**Fix**:
```bash
# Verify license in Secrets Manager
ibmcloud secrets-manager secret --secret-id <LICENSE_CRN>

# Re-encode license if necessary
base64 -i terraform.hclic > license.b64
ibmcloud secrets-manager secret-update --secret-id <LICENSE_CRN> --payload "$(cat license.b64)"

# Restart TFE instance
terraform apply -replace="module.tfe.ibm_is_instance_group.tfe"
```

---

## Next Steps

### Upgrade to Active-Active Mode

```hcl
# Update main.tf
tfe_operational_mode = "active-active"
tfe_instance_count   = 3

# Add Redis password secret (create in Secrets Manager first)
redis_password_secret_crn = "<REDIS_PASSWORD_CRN>"
```

```bash
terraform apply
# Redis cluster provisioned, 3 TFE instances running
```

### Configure VCS Integration

1. Navigate to **Settings** → **Version Control**
2. Choose VCS provider (GitHub, GitLab, Bitbucket)
3. Follow OAuth setup wizard
4. Connect repositories to workspaces

### Set Up SSO/SAML

1. Navigate to **Settings** → **SAML Settings**
2. Upload IdP metadata XML
3. Configure attribute mappings
4. Test SSO login

### Enable Sentinel Policies

1. Navigate to **Settings** → **Policy Sets**
2. Create policy set
3. Add Sentinel policies (e.g., enforce tag requirements)
4. Assign to workspaces

---

## Cost Estimate

Monthly cost for this quickstart configuration (us-south region):

| Resource | Configuration | Monthly Cost (USD) |
|----------|---------------|---------------------|
| VSI | 1x bx2-8x32 (8 vCPU, 32GB) | ~$180 |
| PostgreSQL | 2 members, 4 vCPU, 16GB each | ~$420 |
| Object Storage | 100 GB standard storage | ~$2 |
| Load Balancer | Network Load Balancer | ~$65 |
| Secrets Manager | Standard plan | ~$15 |
| Key Protect | Tiered plan | ~$15 |
| Data Transfer | 500 GB/month | ~$43 |
| **Total** | | **~$740/month** |

**Scaling costs**:
- Active-active mode (3 instances + Redis): +$600/month
- Larger VSI profile (bx2-16x64): +$180/month
- Increased database size (8 vCPU, 32GB): +$420/month

---

## Summary

**You've deployed**:
- ✅ Fully functional TFE instance on IBM Cloud
- ✅ HA PostgreSQL database with automated backups
- ✅ Encrypted Object Storage for artifacts
- ✅ Network Load Balancer with TLS termination
- ✅ Security groups with least-privilege access
- ✅ All secrets managed in Secrets Manager

**Time spent**: ~45 minutes (30 min automated deployment)

**Next**: Explore active-active mode, integrate with VCS, configure SSO, and enable policy enforcement.

**Resources**:
- [Module Documentation](../README.md)
- [IBM Cloud VPC Docs](https://cloud.ibm.com/docs/vpc)
- [TFE Documentation](https://developer.hashicorp.com/terraform/enterprise)
- [Troubleshooting Guide](../docs/troubleshooting.md)
