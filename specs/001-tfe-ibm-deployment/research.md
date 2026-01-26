# Phase 0: Research & Design Decisions

**Feature**: Terraform Enterprise on IBM Cloud (HVD)  
**Date**: 2026-01-26  
**Status**: Complete

## Research Areas

This document resolves all "NEEDS CLARIFICATION" items from the Technical Context and establishes design decisions based on HashiCorp best practices, IBM Cloud platform characteristics, and the AWS HVD reference architecture.

---

## 1. Integration Testing Strategy for Terraform Modules

### Decision: Native Terraform Test Framework (v1.6+)

**Rationale**:
- **Native Terraform Testing** is built into Terraform 1.6+ with `.tftest.hcl` files
- No external dependencies (Go, Ruby, etc.) - uses only Terraform CLI
- Supports both integration testing (`command = apply`) and fast validation (`command = plan`)
- Terraform 1.7+ adds mocking capabilities for unit-style tests
- Simpler to maintain and understand than external frameworks

**Alternatives Considered**:
- **Terratest** (Go-based): Industry standard but adds Go toolchain dependency and complexity
- **terraform-compliance** (BDD-style): Limited to static analysis, doesn't provision real infrastructure
- **Kitchen-Terraform**: Less active community, Ruby-based adds dependency complexity

**Implementation Approach**:
```
tests/
├── basic_deployment.tftest.hcl     # Test FR-001 to FR-005 (core deployment)
├── active_active.tftest.hcl        # Test FR-002 with multi-instance
├── secrets_integration.tftest.hcl  # Test FR-044 to FR-049 (secrets retrieval)
├── plan_validation.tftest.hcl      # Fast validation with command = plan
└── fixtures/
    ├── setup/                      # Helper modules for test prerequisites
    └── test.tfvars                 # Common test variables
```

**Test Coverage Strategy**:
1. **Unit-level**: Variable validation (built into Terraform) + plan-only tests (`command = plan`)
2. **Integration**: Terraform test with `command = apply` deploys real infrastructure in test IBM Cloud account
3. **Contract**: Verify module outputs match expected schema using assertions
4. **Manual**: Air-gapped scenarios tested in isolated environment (too complex for automation)

**Key Testing Challenges**:
- IBM Cloud Database provisioning takes 15-20 minutes (slow test feedback)
- Cost of running full integration tests (~$50-100 per test run)
- Cleanup complexity when tests fail mid-run

**Mitigation**:
- Use `command = plan` for fast validation where possible (no real infrastructure)
- Use smaller database profiles for integration tests (2vCPU/8GB vs production 4vCPU/16GB)
- Implement aggressive resource tagging for automated cleanup
- Gate integration tests behind manual approval in CI/CD (`command = apply` tests)
- Prioritize fast feedback with `terraform validate` and plan-only test runs

**Example Test Structure**:
```hcl
# tests/basic_deployment.tftest.hcl

variables {
  resource_group_id = "test-rg"
  region = "us-south"
  vpc_id = "test-vpc"
  # ... other test variables
}

provider "ibm" {
  region = "us-south"
}

run "setup_prerequisites" {
  module {
    source = "./fixtures/setup"
  }
}

run "validate_plan" {
  command = plan  # Fast validation, no real resources
  
  assert {
    condition     = ibm_is_instance.tfe.profile == "bx2-8x32"
    error_message = "VSI profile mismatch"
  }
}

run "deploy_tfe" {
  command = apply  # Integration test with real infrastructure
  
  assert {
    condition     = output.tfe_url != ""
    error_message = "TFE URL not generated"
  }
}
```

---

## 2. IBM Cloud Service-Specific Patterns and Limitations

### Decision: Adapt AWS HVD Patterns with IBM Cloud Service Constraints

**Key Differences from AWS**:

#### 2.1 Load Balancer Architecture

**IBM Cloud Limitation**: 
- IBM Cloud Load Balancers require explicit listener configuration (no automatic HTTP→HTTPS redirect)
- Health check customization more limited than AWS ALB

**Pattern Adaptation**:
```hcl
# load_balancer.tf
resource "ibm_is_lb" "tfe" {
  type    = var.lb_type  # public or private
  subnets = var.lb_subnet_ids
}

resource "ibm_is_lb_listener" "tfe_https" {
  lb       = ibm_is_lb.tfe.id
  port     = 443
  protocol = "https"
  certificate_instance = var.tls_certificate_crn
  
  # IBM Cloud requires explicit pool association
  default_pool = ibm_is_lb_pool.tfe.id
}

resource "ibm_is_lb_pool" "tfe" {
  lb                  = ibm_is_lb.tfe.id
  name                = "${var.friendly_name_prefix}-tfe-pool"
  protocol            = "https"
  algorithm           = "round_robin"
  health_delay        = 60
  health_retries      = 5
  health_timeout      = 30
  health_type         = "https"
  health_monitor_url  = "/_health_check"
  health_monitor_port = 443
}
```

**Decision Impact**: Module requires more explicit configuration than AWS equivalent but provides same functionality.

#### 2.2 Instance Groups and Autoscaling

**IBM Cloud Pattern**:
- Instance Groups support fixed count and autoscaling policies
- No direct equivalent to AWS Launch Templates (uses instance template)
- Health checks integrate with Load Balancer but require separate configuration

**Implementation**:
```hcl
# compute.tf
resource "ibm_is_instance_template" "tfe" {
  name    = "${var.friendly_name_prefix}-tfe-template"
  image   = data.ibm_is_image.ubuntu.id
  profile = var.instance_profile
  
  primary_network_interface {
    subnet          = var.compute_subnet_ids[0]
    security_groups = [ibm_is_security_group.tfe.id]
  }
  
  vpc  = var.vpc_id
  zone = var.zone
  keys = var.ssh_key_ids
  
  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    tfe_license_secret_id   = var.tfe_license_secret_id
    database_connection_url = ibm_database.postgresql.connectionstrings[0].composed
    # ... other configuration
  })
}

resource "ibm_is_instance_group" "tfe" {
  name              = "${var.friendly_name_prefix}-tfe-ig"
  instance_template = ibm_is_instance_template.tfe.id
  instance_count    = var.tfe_instance_count
  subnets           = var.compute_subnet_ids
  load_balancer     = ibm_is_lb.tfe.id
  load_balancer_pool = ibm_is_lb_pool.tfe.pool_id
  
  application_port = 443
}
```

#### 2.3 Database Service Integration

**IBM Cloud Pattern**: IBM Cloud Databases (ICD) for PostgreSQL
- Provisioning time: 15-20 minutes (slower than RDS)
- Connection strings provided via API (not individual parameters)
- High availability requires explicit replica configuration
- Encryption always enabled (cannot be disabled)

**Connection String Handling**:
```hcl
# database.tf
resource "ibm_database" "postgresql" {
  name              = "${var.friendly_name_prefix}-tfe-db"
  plan              = "standard"
  location          = var.region
  service           = "databases-for-postgresql"
  version           = var.postgresql_version  # "14", "15", etc.
  
  group {
    group_id = "member"
    members {
      allocation_count = var.database_member_count  # 2 for HA
    }
    memory {
      allocation_mb = var.database_memory_mb  # 16384 for 16GB
    }
    disk {
      allocation_mb = var.database_disk_mb  # 20480 for 20GB
    }
    cpu {
      allocation_count = var.database_cpu_count  # 4 for production
    }
  }
  
  adminpassword = var.database_admin_password
  
  # Backup configuration
  backup_id                 = null
  point_in_time_recovery_time = null
  backup_encryption_key_crn = var.kms_key_crn
}

# Output parsed connection parameters for TFE
locals {
  db_connection = ibm_database.postgresql.connectionstrings[0].composed
  # Parse: postgres://admin:password@host:port/ibmclouddb?sslmode=verify-full
  db_host = regex("@([^:]+):", local.db_connection)[0]
  db_port = regex(":([0-9]+)/", local.db_connection)[0]
}
```

**Decision**: Accept 15-20 minute provisioning time; no workaround available. Document in success criteria.

#### 2.4 Object Storage Authentication

**IBM Cloud Pattern**: HMAC credentials or IAM authentication
- Unlike AWS S3 IAM roles, IBM Cloud requires either:
  - HMAC access key/secret key
  - Service ID with IAM authorization policy

**Implementation Decision**: Support both methods via variable toggle
```hcl
# storage.tf
variable "cos_auth_method" {
  type        = string
  description = "Object Storage authentication method"
  validation {
    condition     = contains(["hmac", "iam"], var.cos_auth_method)
    error_message = "Must be 'hmac' or 'iam'."
  }
  default = "iam"
}

# IAM method (recommended)
resource "ibm_iam_authorization_policy" "vsi_to_cos" {
  count = var.cos_auth_method == "iam" ? 1 : 0
  
  source_service_name         = "is"
  source_resource_type        = "instance"
  target_service_name         = "cloud-object-storage"
  target_resource_instance_id = ibm_resource_instance.cos.guid
  roles                       = ["Writer", "Reader"]
}

# HMAC method (for legacy compatibility)
resource "ibm_resource_key" "cos_hmac" {
  count = var.cos_auth_method == "hmac" ? 1 : 0
  
  name                 = "${var.friendly_name_prefix}-cos-hmac"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.cos.id
  
  parameters = {
    HMAC = true
  }
}
```

#### 2.5 Secrets Manager Integration

**IBM Cloud Pattern**: IBM Cloud Secrets Manager
- Similar to AWS Secrets Manager but different API structure
- Secrets identified by CRN (Cloud Resource Name) not ARN
- Supports secret groups for organization
- VSI must authenticate via IAM authorization policy

**Implementation**:
```hcl
# iam.tf
resource "ibm_iam_authorization_policy" "vsi_to_secrets" {
  source_service_name         = "is"
  source_resource_type        = "instance"
  target_service_name         = "secrets-manager"
  target_resource_instance_id = var.secrets_manager_instance_id
  roles                       = ["SecretsReader"]
}

# User data template references secrets by CRN
# templates/user_data.sh.tpl
TFE_LICENSE=$(ibmcloud secrets-manager secret --secret-id ${tfe_license_secret_crn} --output json | jq -r '.secret_data.payload')
```

**Key Limitation**: Secrets Manager API requires IBM Cloud CLI or SDK (no direct file mount like AWS Parameter Store). User data script must include IBM Cloud CLI.

---

## 3. TFE Operational Best Practices for IBM Cloud

### Decision: Follow HashiCorp Reference Architecture with IBM-Specific Adaptations

**Core Operational Patterns**:

#### 3.1 Operational Mode Selection

**Recommendation**: Default to "external" mode, design for easy upgrade to "active-active"

**Rationale**:
- 80% of deployments start single-instance (user story P1 prioritization)
- Active-active adds Redis cost and operational complexity
- All components (LB, networking) should support both modes without redesign

**Variable Design**:
```hcl
variable "tfe_operational_mode" {
  type        = string
  description = "TFE operational mode: 'external' (single instance) or 'active-active' (multi-instance with Redis)"
  validation {
    condition     = contains(["external", "active-active"], var.tfe_operational_mode)
    error_message = "Mode must be 'external' or 'active-active'."
  }
  default = "external"
}

# Conditional Redis provisioning
resource "ibm_database" "redis" {
  count = var.tfe_operational_mode == "active-active" ? 1 : 0
  # ... Redis configuration
}

# Instance count validation
variable "tfe_instance_count" {
  type        = number
  description = "Number of TFE instances (must be 1 for external mode, 2+ for active-active)"
  validation {
    condition = (
      (var.tfe_operational_mode == "external" && var.tfe_instance_count == 1) ||
      (var.tfe_operational_mode == "active-active" && var.tfe_instance_count >= 2)
    )
    error_message = "Instance count must match operational mode: external=1, active-active>=2."
  }
  default = 1
}
```

#### 3.2 Sizing Recommendations

**Decision**: Provide t-shirt sizes as local value presets

**Rationale**: Users struggle with capacity planning; provide tested configurations

**Implementation**:
```hcl
# locals.tf
locals {
  # Preset deployment sizes based on HashiCorp guidance
  deployment_sizes = {
    small = {
      vsi_profile         = "bx2-4x16"    # 4 vCPU, 16GB RAM
      db_cpu              = 2
      db_memory_mb        = 8192
      redis_memory_mb     = 6144          # 6GB
      concurrent_runs     = 10
    }
    medium = {
      vsi_profile         = "bx2-8x32"    # 8 vCPU, 32GB RAM
      db_cpu              = 4
      db_memory_mb        = 16384
      redis_memory_mb     = 12288         # 12GB
      concurrent_runs     = 25
    }
    large = {
      vsi_profile         = "bx2-16x64"   # 16 vCPU, 64GB RAM
      db_cpu              = 8
      db_memory_mb        = 32768
      redis_memory_mb     = 24576         # 24GB
      concurrent_runs     = 50
    }
    custom = {
      # User must provide all values when size = "custom"
    }
  }
  
  selected_size = var.deployment_size == "custom" ? var.custom_sizing : local.deployment_sizes[var.deployment_size]
}

variable "deployment_size" {
  type        = string
  description = "Preset deployment size (small/medium/large) or 'custom' for manual configuration"
  default     = "medium"
}
```

#### 3.3 Network Endpoint Strategy

**Decision**: Default to "hybrid" mode (private backend, public LB)

**Rationale**:
- Most deployments need public access for users
- Backend services (DB, Redis, Object Storage) should be private for security
- Full private mode requires VPN/Direct Link (advanced use case)

**Implementation**:
```hcl
variable "network_connectivity" {
  type        = string
  description = "Network connectivity mode: 'public' (all public), 'hybrid' (public LB, private backend), 'private' (all private)"
  validation {
    condition     = contains(["public", "hybrid", "private"], var.network_connectivity)
    error_message = "Must be 'public', 'hybrid', or 'private'."
  }
  default = "hybrid"
}

# Load balancer type selection
resource "ibm_is_lb" "tfe" {
  type = var.network_connectivity == "private" ? "private" : "public"
  # ...
}

# Database endpoint configuration
resource "ibm_database" "postgresql" {
  service_endpoints = var.network_connectivity == "public" ? "public" : "private"
  # ...
}

# Object Storage endpoint
resource "ibm_cos_bucket" "tfe" {
  # IBM Cloud Object Storage always has private endpoint
  # Public endpoint controlled via bucket policy
  # ...
}
```

#### 3.4 Secret Bootstrap Process

**Decision**: Pre-populate secrets before Terraform apply

**Rationale**:
- Terraform cannot create secrets and consume them in same run (circular dependency)
- Secrets Manager API requires external tooling
- Matches AWS HVD pattern

**Documented Workflow**:
```bash
# 1. User creates secrets in Secrets Manager (manual or separate Terraform)
ibmcloud secrets-manager secret-create \
  --secret-type=arbitrary \
  --name=tfe-license \
  --description="TFE license file" \
  --payload="$(cat terraform.hclic)"

# 2. User provides secret CRNs to module
terraform apply \
  -var="tfe_license_secret_crn=crn:v1:bluemix:public:secrets-manager:..."
```

**Documentation Required**: `docs/tfe-bootstrap-secrets.md` with step-by-step guide

#### 3.5 TFE Version Management

**Decision**: Pin to specific TFE version via image tag variable

**Rationale**:
- Auto-upgrade can cause unexpected downtime
- Different TFE versions have different feature support
- Explicit version control matches Terraform best practices

**Implementation**:
```hcl
variable "tfe_image_tag" {
  type        = string
  description = "TFE container image tag (e.g., 'v202401-1', 'latest'). Pin to specific version for production."
  default     = "v202401-1"  # Example stable version
}

variable "tfe_image_repository" {
  type        = string
  description = "TFE container image repository (use custom registry for air-gapped)"
  default     = "images.releases.hashicorp.com"
}

# templates/user_data.sh.tpl
TFE_IMAGE="${tfe_image_repository}/hashicorp/terraform-enterprise:${tfe_image_tag}"
```

#### 3.6 Backup and Recovery Strategy

**Decision**: Enable automated backups, document manual recovery procedures

**Rationale**:
- Automated backups are low-cost, high-value
- Full DR automation requires complex orchestration (out of scope for module)
- Users need runbooks, not automated failover for most scenarios

**Implementation**:
```hcl
# database.tf
resource "ibm_database" "postgresql" {
  # IBM Cloud Databases auto-backup configuration
  # Note: Always enabled, configure retention only
  
  tags = concat(
    var.common_tags,
    ["backup:enabled", "retention:${var.database_backup_retention_days}days"]
  )
}

variable "database_backup_retention_days" {
  type        = number
  description = "Database backup retention period (1-35 days)"
  validation {
    condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 35
    error_message = "Retention must be between 1 and 35 days."
  }
  default = 35  # Maximum retention
}

# Object Storage versioning for artifact protection
resource "ibm_cos_bucket" "tfe" {
  object_versioning {
    enable = true
  }
}
```

**Documentation Required**: `docs/backup-and-recovery.md` with PITR procedures

---

## 4. Module Variable Naming Conventions

### Decision: Follow AWS HVD Module Conventions with IBM Cloud Adaptations

**Rationale**:
- Consistency with HashiCorp official modules improves adoption
- Users familiar with AWS HVD can migrate knowledge
- Clear naming reduces configuration errors

**Convention Rules**:

1. **Prefix with resource type**: `tfe_*`, `database_*`, `redis_*`, `lb_*`
2. **Use snake_case**: `friendly_name_prefix` not `friendlyNamePrefix`
3. **Boolean flags end in verb**: `enable_*`, `create_*`, `use_*`
4. **IDs end in `_id` or `_ids`**: `vpc_id`, `subnet_ids`, `secret_crn`
5. **Size/capacity in explicit units**: `memory_mb`, `disk_gb`, `timeout_seconds`

**Examples**:
```hcl
# Good
variable "tfe_license_secret_crn" {}
variable "database_memory_mb" {}
variable "enable_active_active" {}
variable "lb_subnet_ids" {}

# Bad (avoid)
variable "license" {}         # Ambiguous: file path or secret ID?
variable "database_memory" {} # Units unclear
variable "active_active" {}   # Boolean should be enable_* or use_*
variable "subnets" {}         # Unclear: compute or LB subnets?
```

---

## 5. Error Handling and Validation Strategy

### Decision: Fail Fast with Comprehensive Variable Validation

**Rationale**:
- IBM Cloud Database provisioning takes 15-20 minutes
- Catching errors before `apply` saves time and money
- FR-067 explicitly requires early validation

**Implementation Pattern**:
```hcl
# variables.tf
variable "tfe_hostname" {
  type        = string
  description = "Fully qualified domain name for TFE (e.g., tfe.example.com)"
  
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", var.tfe_hostname))
    error_message = "Hostname must be a valid FQDN (lowercase letters, numbers, hyphens, dots)."
  }
  
  validation {
    condition     = length(var.tfe_hostname) <= 253
    error_message = "Hostname must not exceed 253 characters (DNS limit)."
  }
}

variable "tfe_license_secret_crn" {
  type        = string
  description = "IBM Cloud CRN of the secret containing TFE license file"
  
  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tfe_license_secret_crn))
    error_message = "Must be a valid IBM Cloud Secrets Manager CRN starting with 'crn:v1:bluemix:public:secrets-manager:'."
  }
}

# Cross-variable validation in locals.tf
locals {
  # Validate instance count matches operational mode
  validate_instance_count = (
    var.tfe_operational_mode == "external" && var.tfe_instance_count != 1 
    ? file("ERROR: external mode requires exactly 1 instance")
    : var.tfe_operational_mode == "active-active" && var.tfe_instance_count < 2
    ? file("ERROR: active-active mode requires 2 or more instances")
    : null
  )
}
```

**Key Validations**:
- CRN format validation for all secret references
- CIDR block format for security group rules
- Mutual exclusivity checks (e.g., can't enable both public and private LB)
- Resource naming compliance (IBM Cloud name constraints)
- Version compatibility (Terraform >= 1.9, provider >= 1.70)

---

## 6. CI/CD and Testing Strategy

### Decision: GitHub Actions with Native Terraform Test

**Rationale**:
- GitHub Actions is zero-cost for public repos
- Native integration with GitHub (where module will be hosted)
- Supports matrix testing across multiple IBM Cloud regions
- Terraform test (v1.6+) requires no additional toolchain (no Go, Python, etc.)

**Pipeline Structure**:
```yaml
# .github/workflows/test.yml
name: Terraform Tests

on:
  pull_request:
    branches: [main]
  workflow_dispatch:  # Manual trigger to control costs

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.9.0
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Init & Validate
        run: |
          terraform init -backend=false
          terraform validate
      
      - name: Run Plan-Only Tests (Fast)
        run: terraform test -filter=tests/plan_validation.tftest.hcl
        env:
          IBM_CLOUD_API_KEY: ${{ secrets.IBM_CLOUD_API_KEY }}
  
  integration-test:
    runs-on: ubuntu-latest
    needs: validate
    if: github.event_name == 'workflow_dispatch'  # Manual approval gate
    strategy:
      matrix:
        region: [us-south, eu-de]
        test: [basic_deployment, active_active, secrets_integration]
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.9.0
      
      - name: Run Terraform Test
        run: terraform test -filter=tests/${{ matrix.test }}.tftest.hcl
        env:
          IBM_CLOUD_API_KEY: ${{ secrets.IBM_CLOUD_API_KEY }}
          TF_VAR_region: ${{ matrix.region }}
        timeout-minutes: 60
```

**Cost Control**:
- Fast plan-only tests run on every PR (no real infrastructure)
- Integration tests (`command = apply`) behind manual approval (workflow_dispatch)
- Terraform automatically cleans up resources after each test file completes
- Use smallest viable instance sizes for testing
- Matrix strategy allows selective test execution

**Test Execution**:
```bash
# Local development - run plan tests only (fast, free)
terraform test -filter=tests/plan_validation.tftest.hcl

# Run specific integration test (provisions real infrastructure)
terraform test -filter=tests/basic_deployment.tftest.hcl

# Run all tests (expensive, use sparingly)
terraform test
```

---

## Summary

All "NEEDS CLARIFICATION" items from Technical Context have been resolved:

| Item | Resolution | Phase |
|------|------------|-------|
| Testing Strategy | Native Terraform test framework (v1.6+) | Phase 0 ✅ |
| IBM Cloud Patterns | Service-specific adaptations documented | Phase 0 ✅ |
| TFE Best Practices | Operational patterns defined | Phase 0 ✅ |

**Next Steps**: Proceed to Phase 1 (Design & Contracts) with confidence that all architectural decisions are grounded in HashiCorp best practices and IBM Cloud platform constraints.

**Key Risk Mitigated**: Database provisioning time (15-20 minutes) is inherent IBM Cloud limitation; no technical workaround available. Documented in success criteria as acceptable constraint.
