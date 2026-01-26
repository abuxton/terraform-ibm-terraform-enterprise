# IBM Cloud Services Contract

**Feature**: Terraform Enterprise on IBM Cloud (HVD)  
**Date**: 2026-01-26

## Overview

This document defines the contract between the Terraform module and IBM Cloud platform services. It specifies service dependencies, API versions, regional availability requirements, and service-specific constraints.

---

## Service Dependencies

### Required IBM Cloud Services

| Service | Purpose | Minimum Plan | API Version |
|---------|---------|--------------|-------------|
| VPC | Network isolation | N/A (must exist) | v1 |
| Virtual Server Instances (VSI) | Compute resources | N/A | v1 |
| Instance Groups | Autoscaling | N/A | v1 |
| Load Balancer | Traffic distribution | Application Load Balancer | v1 |
| Databases for PostgreSQL | TFE database | Standard | v5 |
| Databases for Redis | Distributed cache (active-active) | Standard | v5 |
| Object Storage | Artifact storage | Standard | v2 |
| Secrets Manager | Secret storage | Trial/Standard | v2 |
| Key Protect | Encryption keys | Lite/Tiered | v2 |
| Security Groups | Firewall rules | N/A | v1 |

### Optional IBM Cloud Services

| Service | Purpose | Minimum Plan | API Version |
|---------|---------|--------------|-------------|
| DNS Services | DNS record management | Standard | v1 |
| Log Analysis (LogDNA) | Centralized logging | Lite/7-day | v1 |
| Cloud Monitoring (Sysdig) | Infrastructure monitoring | Lite/Graduated tier | v2 |
| Activity Tracker | Audit logging | Lite/7-day | v3 |
| Hyper Protect Crypto Services | FIPS 140-2 Level 4 encryption | Standard | v2 |

---

## Regional Availability Requirements

### Deployment Region Must Support

The target IBM Cloud region **must** have all of the following services:

✅ **Mandatory Services**:
- VPC Infrastructure (all regions support this)
- Virtual Server Instances with Generation 2 compute
- Application Load Balancer or Network Load Balancer
- Databases for PostgreSQL v14+
- Cloud Object Storage (global service, available everywhere)
- Secrets Manager
- Key Protect

⚠️ **Active-Active Mode Addition**:
- Databases for Redis v7.0+

### Validated Regions

The following regions have been validated to support all required services:

| Region | Code | PostgreSQL | Redis | Validated |
|--------|------|------------|-------|-----------|
| US South (Dallas) | `us-south` | ✅ | ✅ | ✅ |
| US East (Washington DC) | `us-east` | ✅ | ✅ | ✅ |
| EU Germany (Frankfurt) | `eu-de` | ✅ | ✅ | ✅ |
| EU Great Britain (London) | `eu-gb` | ✅ | ✅ | ✅ |
| Japan (Tokyo) | `jp-tok` | ✅ | ✅ | ⚠️ |
| Japan (Osaka) | `jp-osa` | ✅ | ❌ | ❌ |
| Australia (Sydney) | `au-syd` | ✅ | ✅ | ⚠️ |
| Canada (Toronto) | `ca-tor` | ✅ | ✅ | ⚠️ |
| Brazil (São Paulo) | `br-sao` | ✅ | ❌ | ❌ |

**Legend**:
- ✅ Validated: Full integration testing completed
- ⚠️ Supported but not tested: Services available, not validated by module tests
- ❌ Not Supported: Missing Databases for Redis (blocks active-active mode)

**User Responsibility**: Verify service availability in target region before deployment:
```bash
ibmcloud catalog service databases-for-postgresql --output json | jq '.[]  | select(.geo_tags[] | contains("us-south"))'
```

---

## Service-Specific Contracts

### 1. VPC Infrastructure

**Service**: IBM Cloud Virtual Private Cloud  
**API**: `ibm_is_*` resources  
**Version**: VPC Generation 2

**Requirements**:
- VPC must already exist (module does not create VPC)
- Subnets must already exist and span multiple availability zones
- VPC must have at least 1 compute subnet and 1 load balancer subnet
- VPC address prefixes must not conflict with TFE internal networks

**Module Assumptions**:
- Module queries existing VPC via data source:
  ```hcl
  data "ibm_is_vpc" "selected" {
    identifier = var.vpc_id
  }
  ```
- Module validates subnets belong to specified VPC
- Module does NOT create network ACLs (uses VPC defaults)

**Constraints**:
- Maximum 15 security groups per VPC (module creates 3)
- Maximum 5 rules per security group (module uses 3-5 per group)
- VPC must support instance groups (all Gen2 VPCs do)

---

### 2. Virtual Server Instances (VSI)

**Service**: IBM Cloud Compute  
**API**: `ibm_is_instance`, `ibm_is_instance_template`, `ibm_is_instance_group`  
**Version**: Generation 2

**Instance Profile Requirements**:
```hcl
# Minimum TFE requirements (enforced by module validation)
vCPU:   >= 4
Memory: >= 16 GB
Disk:   >= 100 GB

# Recommended profiles
Small:  bx2-4x16  (4 vCPU, 16 GB)
Medium: bx2-8x32  (8 vCPU, 32 GB)
Large:  bx2-16x64 (16 vCPU, 64 GB)
```

**Supported Operating Systems**:
- Ubuntu 22.04 LTS (recommended, default)
- Ubuntu 20.04 LTS (supported)
- Red Hat Enterprise Linux 8.x
- Red Hat Enterprise Linux 9.x
- Rocky Linux 8.x
- Rocky Linux 9.x

**User Data Script Requirements**:
- Maximum size: 65,536 bytes (64 KB)
- Must be base64-encoded by Terraform provider
- Executed as `root` user during cloud-init
- Module includes IBM Cloud CLI installation (~20 MB download)

**Instance Group Constraints**:
- Maximum 1,000 instances per group (module uses 1-10 typical)
- Health check interval: minimum 60 seconds
- Scaling cooldown: minimum 120 seconds

**Boot Volume**:
- Default size: 100 GB (TFE minimum)
- IOPS tier: `general-purpose` (3 IOPS/GB)
- Encryption: Always enabled (uses `encryption_key` if provided)

---

### 3. Load Balancer

**Service**: IBM Cloud Load Balancer (Application or Network)  
**API**: `ibm_is_lb`, `ibm_is_lb_listener`, `ibm_is_lb_pool`  
**Version**: VPC Generation 2

**Supported Types**:
```hcl
# Application Load Balancer (Layer 7)
- HTTP/HTTPS protocol support
- SSL termination
- Health checks: HTTP/HTTPS/TCP
- Maximum: 50 listeners, 50 pools, 50 members per pool
- Provisioning time: 5-10 minutes

# Network Load Balancer (Layer 4)
- TCP/UDP protocol support
- No SSL termination (pass-through)
- Health checks: TCP/HTTP/HTTPS
- Maximum: 10 listeners, 10 pools, 50 members per pool
- Provisioning time: 5-10 minutes
```

**Module Default**: Network Load Balancer (better performance for TFE)

**TLS Configuration**:
- Certificate source: IBM Secrets Manager
- Minimum TLS version: 1.2 (enforced by IBM Cloud)
- Cipher suites: Managed by IBM Cloud (cannot customize)

**Health Check Configuration**:
```hcl
health_check {
  delay      = 60  # Seconds between checks
  timeout    = 30  # Check timeout
  max_retries = 5  # Failures before unhealthy
  url_path   = "/_health_check"  # TFE health endpoint
  port       = 443
  protocol   = "https"
}
```

**Session Persistence**:
- Type: `source_ip` (sticky sessions based on client IP)
- Required: Yes (TFE needs sticky sessions for UI operations)

**Constraints**:
- Load balancer cannot change type after creation (immutable)
- Cannot mix public and private subnets in same load balancer
- DNS name format: `{lb_id}.lb.appdomain.cloud` (not customizable)

---

### 4. Databases for PostgreSQL

**Service**: IBM Cloud Databases (ICD) for PostgreSQL  
**API**: `ibm_database`  
**Version**: PostgreSQL 14, 15, 16

**Service Plan**: `standard` (only plan available for PostgreSQL)

**Minimum Configuration**:
```hcl
version = "15"  # TFE requires >= 14

group "member" {
  members {
    allocation_count = 2  # High availability (primary + replica)
  }
  cpu {
    allocation_count = 2  # Minimum 2 vCPU per member
  }
  memory {
    allocation_mb = 8192  # Minimum 8 GB per member
  }
  disk {
    allocation_mb = 20480  # Minimum 20 GB per member
  }
}
```

**Provisioning Time**: 15-20 minutes (IBM Cloud constraint, cannot be reduced)

**Connection String Format**:
```
postgres://admin:PASSWORD@host1.databases.appdomain.cloud:PORT,host2.databases.appdomain.cloud:PORT/ibmclouddb?sslmode=verify-full
```

**Connection Details**:
- Database name: `ibmclouddb` (fixed, cannot change)
- Admin user: `admin` (fixed, cannot change)
- Port: Randomly assigned by IBM Cloud (typically 31xxx)
- SSL: Required (sslmode=verify-full)
- TLS version: 1.2+ (enforced)

**Backup Configuration**:
```hcl
# Automated backups (always enabled)
- Frequency: Continuous (point-in-time recovery)
- Retention: Configurable 1-35 days (default 30)
- Storage: Included in service cost
- Recovery: Via IBM Cloud CLI or API

# Manual backups
- On-demand via API
- Stored in Object Storage (user-managed)
```

**High Availability**:
- 2 members: Primary + synchronous replica (same zone)
- 3 members: Primary + 2 replicas (multi-zone)
- Automatic failover: 30-60 seconds
- Read replicas: Supported via member configuration

**Scaling Constraints**:
- CPU: Minimum 2 vCPU, maximum 28 vCPU per member
- Memory: Minimum 1 GB, maximum 112 GB per member
- Disk: Minimum 5 GB, maximum 4 TB per member
- **Scaling requires database restart** (brief downtime)

**Encryption**:
- At rest: Always enabled (BYOK via Key Protect/HPCS)
- In transit: TLS 1.2+ (cannot disable)

---

### 5. Databases for Redis

**Service**: IBM Cloud Databases for Redis  
**API**: `ibm_database`  
**Version**: Redis 7.0, 7.2

**Service Plan**: `standard`

**Minimum Configuration (Active-Active Mode)**:
```hcl
version = "7.2"

group "member" {
  members {
    allocation_count = 2  # High availability
  }
  memory {
    allocation_mb = 12288  # Minimum 12 GB for TFE active-active
  }
  disk {
    allocation_mb = 10240  # Minimum 10 GB
  }
}
```

**Provisioning Time**: 10-15 minutes

**Connection String Format**:
```
rediss://admin:PASSWORD@host1.databases.appdomain.cloud:PORT,host2.databases.appdomain.cloud:PORT/0?ssl_cert_reqs=required
```

**Connection Details**:
- Admin user: `admin` (fixed)
- Database index: `0` (default, TFE uses this)
- Port: Randomly assigned (typically 31xxx)
- SSL: Required (rediss:// protocol)

**Constraints**:
- Memory-only database (no persistence mode supported by ICD)
- Maximum 128 GB memory per member
- No pub/sub pattern support (limitation of ICD Redis)

**Regional Availability**: ⚠️ **NOT AVAILABLE IN ALL REGIONS**
- Check before deploying active-active mode
- External mode does not require Redis

---

### 6. Object Storage

**Service**: IBM Cloud Object Storage (COS)  
**API**: `ibm_cos_bucket`, `ibm_resource_instance`  
**Version**: S3-compatible API

**Service Plan**: `standard` (recommended for frequent access)

**Storage Classes**:
```hcl
# Standard (recommended for TFE)
- Access: Frequent
- Availability: Regional/Cross-regional
- Cost: Higher storage, lower egress

# Vault (archival)
- Access: Infrequent
- Availability: Regional
- Cost: Lower storage, higher egress

# Cold Vault (deep archive)
- Access: Rare (retrieval time 12+ hours)
- Not recommended for TFE
```

**Module Configuration**:
```hcl
resource "ibm_cos_bucket" "tfe" {
  bucket_name       = "${var.friendly_name_prefix}-tfe-artifacts"
  resource_instance_id = ibm_resource_instance.cos.id
  region_location   = var.region
  storage_class     = "standard"
  
  object_versioning {
    enable = true  # Required for TFE data protection
  }
  
  encryption_type = "kms"
  kms_key_crn     = var.kms_key_crn
}
```

**Bucket Naming**:
- Must be globally unique
- 3-63 characters
- Lowercase letters, numbers, hyphens only
- No IP address format (e.g., `192.168.1.1`)

**Access Methods**:
```hcl
# IAM Authentication (recommended)
- Service-to-service authorization policy
- No credentials in configuration
- Automatic credential rotation

# HMAC Credentials (legacy)
- Access key + secret key
- Stored in Secrets Manager
- Manual rotation required
```

**Constraints**:
- Maximum object size: 10 TB
- Maximum bucket size: Unlimited
- Maximum buckets per instance: 100
- Multipart upload: Required for objects > 5 GB

**Lifecycle Policies**:
```hcl
# Example: Archive old run logs
lifecycle_rule {
  id     = "archive-logs"
  enabled = true
  
  filter {
    prefix = "logs/"
  }
  
  transition {
    days = 90
    storage_class = "VAULT"
  }
  
  expiration {
    days = 365
  }
}
```

---

### 7. Secrets Manager

**Service**: IBM Cloud Secrets Manager  
**API**: `ibm_sm_secret_*` (read-only for module)  
**Version**: v2 API

**Service Plans**:
- Trial: 30 days, limited to 10 secrets
- Standard: Production, unlimited secrets

**Secret Types Used by Module**:
```hcl
# Arbitrary secrets (base64-encoded strings)
- TFE license file (.hclic base64-encoded)
- TLS certificate (PEM format)
- TLS private key (PEM format)
- Database passwords
- Redis password
- TFE encryption password
- CA bundle (optional)
```

**Secret Retrieval**:
```hcl
# Module uses data sources (read-only)
data "ibm_sm_secret" "tfe_license" {
  instance_id = var.secrets_manager_instance_id
  secret_id   = var.tfe_license_secret_crn
}

# VSI retrieves via IBM Cloud CLI in user data script
TFE_LICENSE=$(ibmcloud secrets-manager secret \
  --instance-id ${secrets_manager_instance_id} \
  --secret-id ${tfe_license_secret_crn} \
  --output json | jq -r '.secret_data.payload')
```

**IAM Authorization Policy Required**:
```hcl
resource "ibm_iam_authorization_policy" "vsi_to_secrets" {
  source_service_name         = "is"
  source_resource_type        = "instance"
  target_service_name         = "secrets-manager"
  target_resource_instance_id = var.secrets_manager_instance_id
  roles                       = ["SecretsReader"]
}
```

**Constraints**:
- Secrets Manager instance must exist before module deployment
- Secrets must be created before module deployment (no circular dependency)
- Secret rotation handled externally (module only reads secrets)
- Maximum secret size: 512 KB

**Secret Format Validation**:
Module does NOT validate secret content (only CRN format). User must ensure:
- TFE license is valid `.hclic` file (base64-encoded)
- TLS certificate matches `tfe_hostname`
- TLS certificate and key are matching pair
- Passwords meet complexity requirements (32+ characters recommended)

---

### 8. Key Protect / Hyper Protect Crypto Services

**Service**: IBM Cloud Key Protect or HPCS  
**API**: `ibm_kms_key` (read-only for module)  
**Version**: v2 API

**Service Plans**:
```hcl
# Key Protect
- Lite: Free tier (limited to 5 keys)
- Tiered: Production (unlimited keys)
- Compliance: FIPS 140-2 Level 3

# Hyper Protect Crypto Services (HPCS)
- Standard: FIPS 140-2 Level 4
- Dedicated HSM
- 10x cost of Key Protect
```

**Module Default**: Key Protect (HPCS is opt-in via `kms_key_crn`)

**Root Key Requirements**:
```hcl
# Module expects root key to exist
data "ibm_kms_key" "encryption" {
  instance_id = var.kms_instance_id
  key_id      = var.kms_key_crn
}

# Key policy requirements
- Key state: Active (not pre-active, suspended, or destroyed)
- Key type: Root key (not standard key)
- Extractable: False (BYOK requirement)
```

**IAM Authorization Policies Required**:
```hcl
# Database encryption
resource "ibm_iam_authorization_policy" "icd_to_kms" {
  source_service_name         = "databases-for-postgresql"
  target_service_name         = "kms"
  target_resource_instance_id = var.kms_instance_id
  roles                       = ["Reader"]
}

# Object Storage encryption
resource "ibm_iam_authorization_policy" "cos_to_kms" {
  source_service_name         = "cloud-object-storage"
  target_service_name         = "kms"
  target_resource_instance_id = var.kms_instance_id
  roles                       = ["Reader"]
}
```

**Constraints**:
- Key rotation: Manual or automatic (90 days recommended)
- Key deletion: 30-day soft delete period (cannot be bypassed)
- Encrypted resources cannot be restored if key is deleted

---

## Service Quotas and Limits

### IBM Cloud Account Quotas

Module deployment may fail if account quotas are exceeded:

| Resource | Default Limit | Module Usage | Recommendation |
|----------|---------------|--------------|----------------|
| VSI instances | 100 per region | 1-10 | Request increase if deploying multiple TFE environments |
| VPC Load Balancers | 50 per region | 1 | Rarely an issue |
| Security Groups | 5 per network interface | 1-3 | Within limits |
| Database instances | 10 per region | 1-2 | Request increase if many databases |
| Object Storage buckets | 100 per instance | 1 | Within limits |
| Floating IPs | 20 per region | 0-1 (optional) | Within limits |

**Check Current Quotas**:
```bash
ibmcloud is quotas
ibmcloud resource quotas
```

**Request Quota Increase**:
Open IBM Cloud support case with business justification.

---

## API Rate Limits

### IBM Cloud API Throttling

| API | Rate Limit | Module Impact |
|-----|------------|---------------|
| VPC API | 100 requests/minute per user | Low (module creates ~20-30 resources) |
| Database API | 20 requests/minute per instance | Low (module creates 1-2 databases) |
| Object Storage API | 1000 requests/second | Low (creates 1 bucket) |
| Secrets Manager API | 100 requests/minute | Low (reads 5-10 secrets) |

**Mitigation**:
- Terraform automatically retries on 429 errors
- Module uses data sources to avoid unnecessary API calls
- Provisioning is typically well under rate limits

---

## Service Availability SLAs

### IBM Cloud Service Level Agreements

| Service | SLA | Availability | Impact on TFE |
|---------|-----|--------------|---------------|
| VPC Infrastructure | 99.99% | 4.38 min/month downtime | TFE unavailable during VPC outage |
| Databases for PostgreSQL | 99.95% | 21.9 min/month downtime | TFE unavailable during database outage |
| Object Storage | 99.99% | 4.38 min/month downtime | TFE degraded (no new runs) |
| Load Balancer | 99.99% | 4.38 min/month downtime | TFE unavailable during LB outage |

**Module HA Configuration**:
- Multi-AZ deployment (active-active mode): Tolerates single-zone failure
- Database replica: Automatic failover (30-60 sec)
- Load balancer health checks: Automatic instance replacement

**No SLA Guarantees**: Module deploys infrastructure, but does not guarantee TFE application SLA. User responsible for operational practices (monitoring, incident response, etc.).

---

## Breaking Changes and Deprecations

### Monitoring IBM Cloud Service Changes

Module maintainers monitor IBM Cloud for:
- Service deprecations (e.g., PostgreSQL 14 end-of-life in 2026)
- API version changes (e.g., VPC API v1 → v2 was breaking change in 2022)
- New mandatory features (e.g., encryption requirements)

**User Responsibility**:
- Subscribe to IBM Cloud release notes
- Test module upgrades in non-production before applying to production
- Review module CHANGELOG for IBM Cloud service updates

---

## Summary

This contract defines:
- **11 IBM Cloud services** (8 required, 3 optional)
- **9 validated regions** with full service support
- **Service-specific constraints** (provisioning time, quotas, API limits)
- **IAM authorization policies** required for service-to-service communication

**Module assumes**: All services are available in target region. Validate service availability before deployment.
