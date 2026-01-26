# Phase 1: Data Model & Domain Entities

**Feature**: Terraform Enterprise on IBM Cloud (HVD)  
**Date**: 2026-01-26  
**Status**: Complete

## Overview

This document defines the core entities and their relationships for the TFE IBM Cloud deployment module. These entities map to IBM Cloud resources and their configurations, representing the infrastructure-as-code data model.

---

## Core Entities

### 1. TFE Deployment Configuration

**Description**: Top-level deployment configuration combining all component specifications.

**Attributes**:
```hcl
{
  friendly_name_prefix: string          # Resource naming prefix (e.g., "prod-tfe")
  tfe_operational_mode: enum            # "external" | "active-active"
  tfe_hostname: string                  # FQDN (e.g., "tfe.example.com")
  tfe_image_tag: string                 # TFE version (e.g., "v202401-1")
  tfe_image_repository: string          # Container registry URL
  deployment_size: enum                 # "small" | "medium" | "large" | "custom"
  network_connectivity: enum            # "public" | "hybrid" | "private"
  region: string                        # IBM Cloud region (e.g., "us-south")
  resource_group_id: string             # IBM Cloud resource group
  common_tags: list(string)             # Resource tags for cost allocation
}
```

**Relationships**:
- Has one `ComputeCluster`
- Has one `DatabaseCluster`
- Has zero or one `RedisCluster` (conditional on active-active mode)
- Has one `ObjectStorageBucket`
- Has one `LoadBalancer`
- Has one `NetworkConfiguration`
- Has one `SecretsConfiguration`

**Validation Rules**:
- `friendly_name_prefix` must match `^[a-z][a-z0-9-]*$` (lowercase, alphanumeric, hyphens)
- `tfe_hostname` must be valid FQDN (max 253 chars)
- `deployment_size` = "custom" requires all custom sizing variables
- `tfe_operational_mode` = "active-active" requires `RedisCluster`

**State Transitions**:
```
[Initial] → [Planned] → [Creating] → [Running] → [Updating] → [Running]
                              ↓
                          [Failed] → [Destroying] → [Destroyed]
```

---

### 2. ComputeCluster

**Description**: Collection of Virtual Server Instances running TFE application containers.

**Attributes**:
```hcl
{
  instance_template_id: string          # VSI template reference
  instance_profile: string              # Profile name (e.g., "bx2-8x32")
  instance_count: number                # Number of VSI instances (1 for external, 2+ for active-active)
  image_id: string                      # Base OS image (Ubuntu/RHEL/Rocky)
  ssh_key_ids: list(string)             # SSH key CRNs for access
  user_data_script: string              # Cloud-init script content
  subnet_ids: list(string)              # Compute subnet CRNs (multi-AZ)
  security_group_id: string             # Security group CRN
  block_storage_profile: string         # IOPS tier (e.g., "10iops-tier")
  block_storage_capacity_gb: number     # Disk size in GB
  enable_floating_ip: bool              # Public IP assignment (for debugging)
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Has many `VSIInstance` (actual compute instances)
- Uses one `NetworkConfiguration.compute_security_group`
- Mounts one `ObjectStorageBucket` (via environment variables)
- Connects to one `DatabaseCluster`
- Connects to zero or one `RedisCluster`

**Validation Rules**:
- `instance_count` must equal 1 if `tfe_operational_mode` = "external"
- `instance_count` must be >= 2 if `tfe_operational_mode` = "active-active"
- `instance_profile` must meet minimum: 4 vCPU, 16GB RAM
- `subnet_ids` must be in same VPC and different availability zones
- `block_storage_capacity_gb` >= 100 (TFE minimum requirement)

**Lifecycle**:
- Instance group manages VSI creation/destruction
- Health checks via load balancer determine instance replacement
- User data script executes on every instance launch

---

### 3. VSIInstance

**Description**: Individual Virtual Server Instance running TFE container.

**Attributes**:
```hcl
{
  instance_id: string                   # IBM Cloud VSI ID
  name: string                          # Instance name
  zone: string                          # Availability zone
  primary_ipv4_address: string          # Private IP
  status: enum                          # "pending" | "running" | "stopping" | "stopped"
  health_status: enum                   # "healthy" | "unhealthy" | "unknown"
  created_at: timestamp
  last_health_check: timestamp
}
```

**Relationships**:
- Belongs to one `ComputeCluster`
- Registered with one `LoadBalancerPool`
- Has IAM policies to access `SecretsConfiguration`, `ObjectStorageBucket`, `DatabaseCluster`

**Validation Rules**:
- Must have private IP in compute subnet CIDR range
- Health check failures > 5 consecutive trigger replacement

---

### 4. DatabaseCluster

**Description**: IBM Cloud Databases for PostgreSQL cluster providing TFE metadata storage.

**Attributes**:
```hcl
{
  instance_id: string                   # ICD instance ID
  service_plan: string                  # "standard" | "enterprise"
  version: string                       # PostgreSQL version (e.g., "14", "15")
  member_count: number                  # 2 for HA, 3 for multi-zone HA
  cpu_allocation_count: number          # vCPU per member
  memory_allocation_mb: number          # Memory in MB per member
  disk_allocation_mb: number            # Storage in MB per member
  backup_retention_days: number         # 1-35 days
  service_endpoints: enum               # "public" | "private" | "public-and-private"
  encryption_key_crn: string            # Key Protect CRN
  connection_string: string             # Composed connection URL (computed)
  admin_password_secret_crn: string     # Secrets Manager CRN
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Connected to by `ComputeCluster` instances
- Credentials stored in `SecretsConfiguration`
- Encrypted by key in `EncryptionConfiguration`

**Validation Rules**:
- `version` >= "14" (TFE requirement)
- `cpu_allocation_count` >= 2 (minimum for production)
- `memory_allocation_mb` >= 8192 (8GB minimum)
- `disk_allocation_mb` >= 20480 (20GB minimum)
- `member_count` must be 2 or 3 (HA configurations)
- `backup_retention_days` in range [1, 35]

**Connection String Format**:
```
postgres://admin:PASSWORD@host1:port,host2:port/ibmclouddb?sslmode=verify-full
```

---

### 5. RedisCluster

**Description**: IBM Cloud Databases for Redis providing distributed caching and locking for active-active TFE.

**Attributes**:
```hcl
{
  instance_id: string                   # ICD instance ID
  service_plan: string                  # "standard"
  version: string                       # Redis version (e.g., "7.0", "7.2")
  member_count: number                  # 2 for HA
  memory_allocation_mb: number          # Memory per member (min 12GB for TFE)
  service_endpoints: enum               # "public" | "private"
  encryption_key_crn: string            # Key Protect CRN
  connection_string: string             # Computed connection URL
  password_secret_crn: string           # Secrets Manager CRN
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Connected to by `ComputeCluster` instances (only in active-active mode)
- Credentials stored in `SecretsConfiguration`
- Only created when `tfe_operational_mode` = "active-active"

**Validation Rules**:
- `version` >= "7.0" (TFE requirement)
- `memory_allocation_mb` >= 12288 (12GB minimum for production active-active)
- `member_count` must be 2 (HA configuration)
- Must exist if and only if `tfe_operational_mode` = "active-active"

**Connection String Format**:
```
rediss://admin:PASSWORD@host1:port,host2:port/0?ssl_cert_reqs=required
```

---

### 6. ObjectStorageBucket

**Description**: IBM Cloud Object Storage bucket storing TFE artifacts, state files, and logs.

**Attributes**:
```hcl
{
  bucket_name: string                   # Unique bucket name
  region_location: string               # Regional bucket location
  storage_class: enum                   # "standard" | "vault" | "cold" | "smart"
  versioning_enabled: bool              # Object versioning for protection
  encryption_key_crn: string            # Key Protect CRN
  lifecycle_rules: list(object)         # Automated archival/deletion rules
  public_access_blocked: bool           # Block all public access
  activity_tracking_enabled: bool       # Audit logging
  auth_method: enum                     # "iam" | "hmac"
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Accessed by `ComputeCluster` instances via IAM policy or HMAC credentials
- Encrypted by key in `EncryptionConfiguration`
- Lifecycle managed by `lifecycle_rules`

**Validation Rules**:
- `bucket_name` must be globally unique, lowercase, 3-63 chars
- `storage_class` = "standard" recommended for TFE (frequent access)
- `versioning_enabled` must be true (data protection requirement)
- `public_access_blocked` must be true (security requirement)
- `auth_method` = "iam" recommended over "hmac"

**Bucket Structure**:
```
/{prefix}/
  /artifacts/          # Terraform module/provider artifacts
  /state/              # Workspace state files
  /logs/               # Run logs
  /backups/            # Manual backup archives
```

---

### 7. LoadBalancer

**Description**: IBM Cloud Load Balancer (ALB or NLB) distributing traffic to TFE instances.

**Attributes**:
```hcl
{
  lb_id: string                         # Load balancer ID
  lb_type: enum                         # "public" | "private"
  dns_name: string                      # LB DNS endpoint (computed)
  subnet_ids: list(string)              # LB subnet CRNs (multi-AZ)
  security_group_id: string             # Security group CRN
  listener_port: number                 # 443 (HTTPS)
  listener_protocol: enum               # "https" | "tcp"
  certificate_crn: string               # TLS certificate CRN
  pool_algorithm: enum                  # "round_robin" | "weighted_round_robin" | "least_connections"
  pool_health_check: object {
    delay: number                       # Seconds between checks (60)
    timeout: number                     # Check timeout (30)
    max_retries: number                 # Failures before unhealthy (5)
    url_path: string                    # "/_health_check"
    port: number                        # 443
  }
  session_persistence: bool             # Sticky sessions (true for TFE)
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Has one `LoadBalancerPool` containing `VSIInstance` members
- Uses `NetworkConfiguration.lb_security_group`
- TLS certificate from `SecretsConfiguration`

**Validation Rules**:
- `listener_port` must be 443 (TFE standard)
- `listener_protocol` must be "https" (TLS required)
- `certificate_crn` must be valid Secrets Manager certificate CRN
- `pool_health_check.url_path` must be "/_health_check" (TFE endpoint)
- `subnet_ids` must span multiple AZs for HA
- `session_persistence` must be true (TFE requires sticky sessions for some operations)

---

### 8. NetworkConfiguration

**Description**: VPC networking components including security groups and firewall rules.

**Attributes**:
```hcl
{
  vpc_id: string                        # Existing VPC CRN
  compute_subnet_ids: list(string)      # Subnets for TFE instances
  lb_subnet_ids: list(string)           # Subnets for load balancer
  database_subnet_ids: list(string)     # Subnets for database (optional, can share with compute)
  
  # Security groups
  compute_security_group_id: string
  lb_security_group_id: string
  database_security_group_id: string
  
  # Firewall rules
  ingress_cidr_blocks_https: list(string)   # Allowed HTTPS sources
  ingress_cidr_blocks_ssh: list(string)     # Allowed SSH sources (management)
  enable_metrics_endpoint: bool             # Expose port 9091 for metrics
  metrics_cidr_blocks: list(string)         # Allowed metrics scraper IPs
}
```

**Security Group Rules**:

**Compute Security Group**:
```hcl
ingress {
  # HTTPS from load balancer
  from_port = 443
  to_port = 443
  protocol = "tcp"
  source_security_group = lb_security_group_id
}

ingress {
  # SSH from management CIDR (optional)
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = var.ingress_cidr_blocks_ssh
}

ingress {
  # Metrics endpoint (optional)
  from_port = 9091
  to_port = 9091
  protocol = "tcp"
  cidr_blocks = var.metrics_cidr_blocks
}

egress {
  # All outbound (database, redis, object storage, internet)
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**Load Balancer Security Group**:
```hcl
ingress {
  # HTTPS from allowed sources
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = var.ingress_cidr_blocks_https
}

egress {
  # To TFE instances
  from_port = 443
  to_port = 443
  protocol = "tcp"
  destination_security_group = compute_security_group_id
}
```

**Database Security Group**:
```hcl
ingress {
  # PostgreSQL from TFE instances
  from_port = 5432
  to_port = 5432
  protocol = "tcp"
  source_security_group = compute_security_group_id
}

ingress {
  # Redis from TFE instances (if active-active)
  from_port = 6379
  to_port = 6379
  protocol = "tcp"
  source_security_group = compute_security_group_id
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Used by `ComputeCluster`, `LoadBalancer`, `DatabaseCluster`
- References existing VPC (not created by module)

**Validation Rules**:
- All subnets must be in same VPC
- Subnets should span multiple AZs (recommendation, not enforced)
- `ingress_cidr_blocks_https` must not be empty (at least one allowed source)
- `ingress_cidr_blocks_ssh` can be empty (SSH access optional)
- CIDR blocks must be valid IPv4 CIDR notation

---

### 9. SecretsConfiguration

**Description**: References to secrets stored in IBM Cloud Secrets Manager.

**Attributes**:
```hcl
{
  secrets_manager_instance_id: string         # Secrets Manager instance CRN
  tfe_license_secret_crn: string              # TFE license file secret
  tls_certificate_secret_crn: string          # TLS certificate secret (PEM)
  tls_private_key_secret_crn: string          # TLS private key secret (PEM)
  tfe_encryption_password_secret_crn: string  # TFE internal encryption password
  database_admin_password_secret_crn: string  # PostgreSQL admin password
  redis_password_secret_crn: string           # Redis password (optional)
  ca_bundle_secret_crn: string                # Custom CA bundle (optional)
  cos_hmac_access_key_secret_crn: string      # Object Storage HMAC key (optional)
  cos_hmac_secret_key_secret_crn: string      # Object Storage HMAC secret (optional)
}
```

**Secret Format Requirements**:

**TFE License** (`tfe_license_secret_crn`):
```json
{
  "secret_type": "arbitrary",
  "payload": "<BASE64_ENCODED_HCLIC_FILE>"
}
```

**TLS Certificate** (`tls_certificate_secret_crn`):
```json
{
  "secret_type": "arbitrary",
  "payload": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
}
```

**Database Password** (`database_admin_password_secret_crn`):
```json
{
  "secret_type": "arbitrary",
  "payload": "<RANDOM_STRING_32_CHARS>"
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Secrets consumed by `ComputeCluster` instances at boot time
- IAM authorization policy required: VSI → Secrets Manager

**Validation Rules**:
- All CRNs must start with `crn:v1:bluemix:public:secrets-manager:`
- `redis_password_secret_crn` required if `tfe_operational_mode` = "active-active"
- HMAC credentials required if `ObjectStorageBucket.auth_method` = "hmac"
- `ca_bundle_secret_crn` optional (only for private CA environments)

**Security Requirements**:
- Secrets never stored in Terraform state (only CRN references)
- VSI retrieves secrets at boot via IBM Cloud CLI/SDK
- Secret rotation handled externally (module does not rotate)

---

### 10. EncryptionConfiguration

**Description**: Encryption key management via IBM Cloud Key Protect or Hyper Protect Crypto Services.

**Attributes**:
```hcl
{
  kms_service: enum                     # "keyprotect" | "hpcs"
  kms_instance_crn: string              # KMS instance CRN
  root_key_crn: string                  # Master encryption key CRN
  
  # Encryption targets
  database_encryption_enabled: bool     # Always true (ICD requirement)
  redis_encryption_enabled: bool        # Always true (ICD requirement)
  object_storage_encryption_enabled: bool  # Always true (security requirement)
  block_storage_encryption_enabled: bool   # Optional (default: IBM-managed)
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Root key encrypts `DatabaseCluster`, `RedisCluster`, `ObjectStorageBucket`
- IAM authorization policies required: ICD → KMS, COS → KMS

**Validation Rules**:
- `root_key_crn` must be valid Key Protect or HPCS CRN
- All `*_encryption_enabled` flags must be true (enforced by IBM Cloud)
- HPCS provides FIPS 140-2 Level 4 (optional upgrade from Key Protect)

---

### 11. ObservabilityConfiguration

**Description**: Logging and monitoring integration settings.

**Attributes**:
```hcl
{
  # Logging
  enable_log_forwarding: bool
  log_forwarding_destination: enum      # "logdna" | "cos" | "custom"
  logdna_instance_crn: string           # IBM Log Analysis instance (if destination = logdna)
  log_cos_bucket_name: string           # COS bucket for logs (if destination = cos)
  custom_fluentbit_config: string       # Custom Fluent Bit config (if destination = custom)
  
  # Monitoring
  enable_monitoring: bool
  monitoring_instance_crn: string       # IBM Cloud Monitoring instance
  enable_metrics_endpoint: bool         # Expose TFE metrics port
  metrics_port: number                  # 9091 (HTTPS) or 9090 (HTTP)
  
  # Activity Tracking
  enable_activity_tracker: bool         # Audit logging for all services
  activity_tracker_instance_crn: string
}
```

**Relationships**:
- Belongs to one `TFEDeploymentConfiguration`
- Fluent Bit config deployed to `ComputeCluster` instances via user data
- Metrics scraped from `VSIInstance` endpoints

**Validation Rules**:
- If `enable_log_forwarding` = true, must specify destination and corresponding CRN
- `metrics_port` = 9091 recommended (HTTPS), 9090 for legacy compatibility
- Activity Tracker should be enabled for production (audit compliance)

**Log Categories**:
- Application logs: TFE container stdout/stderr
- System logs: Cloud-init, Docker daemon
- Audit logs: IBM Cloud API calls (via Activity Tracker)

---

## Entity Relationships Diagram

```
TFEDeploymentConfiguration
    ├── ComputeCluster (1)
    │   ├── VSIInstance (1..n)
    │   └── uses → NetworkConfiguration.compute_security_group
    │
    ├── DatabaseCluster (1)
    │   ├── encrypted_by → EncryptionConfiguration.root_key
    │   └── credentials_in → SecretsConfiguration.database_admin_password
    │
    ├── RedisCluster (0..1)  # Only if active-active
    │   ├── encrypted_by → EncryptionConfiguration.root_key
    │   └── credentials_in → SecretsConfiguration.redis_password
    │
    ├── ObjectStorageBucket (1)
    │   ├── encrypted_by → EncryptionConfiguration.root_key
    │   └── accessed_by → ComputeCluster (IAM policy)
    │
    ├── LoadBalancer (1)
    │   ├── backend_pool → VSIInstance (n)
    │   ├── certificate_from → SecretsConfiguration.tls_certificate
    │   └── uses → NetworkConfiguration.lb_security_group
    │
    ├── NetworkConfiguration (1)
    │   ├── compute_security_group → ComputeCluster
    │   ├── lb_security_group → LoadBalancer
    │   └── database_security_group → DatabaseCluster, RedisCluster
    │
    ├── SecretsConfiguration (1)
    │   └── accessed_by → ComputeCluster (IAM policy)
    │
    ├── EncryptionConfiguration (1)
    │   ├── encrypts → DatabaseCluster
    │   ├── encrypts → RedisCluster
    │   └── encrypts → ObjectStorageBucket
    │
    └── ObservabilityConfiguration (1)
        └── deployed_to → ComputeCluster
```

---

## Data Flow Sequences

### 1. Initial Deployment Flow

```
1. Terraform Plan
   → Validate all variables (CRN formats, CIDR blocks, instance counts)
   → Check VPC and subnets exist
   → Verify secrets exist in Secrets Manager (data source lookup)

2. Terraform Apply
   → Create EncryptionConfiguration (Key Protect key)
   → Create NetworkConfiguration (security groups)
   → Create DatabaseCluster (15-20 min provisioning)
   → Create RedisCluster (if active-active) (10-15 min)
   → Create ObjectStorageBucket (< 1 min)
   → Create LoadBalancer (5-10 min)
   → Create ComputeCluster (instance template + instance group)
   → Launch VSIInstance(s) (5-10 min)
       → User data script executes:
           a. Install IBM Cloud CLI
           b. Retrieve secrets from Secrets Manager
           c. Configure TFE environment variables
           d. Pull TFE container image
           e. Start TFE application (docker-compose)
   → VSI health checks start passing (5-10 min)
   → Load balancer adds VSI to pool
   → TFE accessible via HTTPS

Total time: ~30 minutes (database is bottleneck)
```

### 2. TFE Workspace Execution Flow

```
1. User creates workspace in TFE UI
   → Workspace metadata stored in DatabaseCluster

2. User queues Terraform run
   → Run metadata stored in DatabaseCluster
   → Run assigned to VSIInstance by TFE scheduler

3. VSIInstance executes run
   → Clone repository (from VCS)
   → Download Terraform providers (to ObjectStorageBucket cache)
   → Execute terraform plan/apply
   → Stream logs to DatabaseCluster
   → Store state file in ObjectStorageBucket
   → Store plan file in ObjectStorageBucket

4. Run completes
   → Update run status in DatabaseCluster
   → Trigger webhooks (if configured)
```

### 3. Secrets Rotation Flow

```
1. Admin updates secret in Secrets Manager
   → New certificate, password, or license file

2. (Manual) Admin triggers VSI instance refresh
   → Terraform: terraform apply -replace="ibm_is_instance_group.tfe"
   → OR: Instance group rolling update (if supported)

3. New VSIInstance launches
   → User data retrieves NEW secret version
   → TFE starts with updated configuration

4. Load balancer health check detects new instance healthy
   → Adds to pool

5. Old VSIInstance drained and terminated
   → Rolling update completes without downtime (active-active mode)
```

### 4. Scale-Up Flow (External → Active-Active)

```
1. Admin updates Terraform variables
   tfe_operational_mode = "active-active"
   tfe_instance_count = 3

2. Terraform plan shows:
   + RedisCluster (new)
   ~ ComputeCluster.instance_count: 1 → 3 (update)
   ~ VSIInstance user_data: add Redis config (replacement)

3. Terraform apply
   → Create RedisCluster (10-15 min)
   → Update instance template with Redis connection
   → Instance group scales to 3 instances
   → New VSIs retrieve Redis config from environment
   → Load balancer distributes traffic across all 3

4. Active-active mode operational
   → Concurrent runs supported
   → Distributed locking via Redis
```

---

## Computed Values

### 1. Database Connection Parameters

Derived from `ibm_database.postgresql.connectionstrings[0].composed`:

```hcl
locals {
  db_connection_string = ibm_database.postgresql.connectionstrings[0].composed
  # Format: postgres://admin:PASSWORD@host1:port1,host2:port2/ibmclouddb?sslmode=verify-full
  
  db_host     = regex("@([^:,]+)", local.db_connection_string)[0]
  db_port     = regex(":([0-9]+)", local.db_connection_string)[0]
  db_name     = "ibmclouddb"  # Fixed by IBM Cloud Databases
  db_user     = "admin"       # Fixed by IBM Cloud Databases
  db_password = var.database_admin_password  # From Secrets Manager
}
```

### 2. TFE Application URL

```hcl
locals {
  tfe_url = "https://${var.tfe_hostname}"
  tfe_admin_url = "${local.tfe_url}/admin/account/new"
}
```

### 3. Resource Naming

```hcl
locals {
  compute_name  = "${var.friendly_name_prefix}-tfe-vsi"
  database_name = "${var.friendly_name_prefix}-tfe-db"
  redis_name    = "${var.friendly_name_prefix}-tfe-redis"
  bucket_name   = "${var.friendly_name_prefix}-tfe-artifacts"
  lb_name       = "${var.friendly_name_prefix}-tfe-lb"
}
```

---

## Summary

The data model defines 11 core entities representing the IBM Cloud infrastructure for TFE deployment. Key characteristics:

- **Hierarchical**: All entities belong to `TFEDeploymentConfiguration`
- **Conditional**: `RedisCluster` only exists in active-active mode
- **Validated**: Extensive validation rules prevent invalid configurations
- **Encrypted**: All data at rest encrypted via `EncryptionConfiguration`
- **Secure**: All secrets referenced by CRN, never stored in state

**Next Phase**: Define contracts (module interface, IBM Cloud service requirements, secrets schema).
