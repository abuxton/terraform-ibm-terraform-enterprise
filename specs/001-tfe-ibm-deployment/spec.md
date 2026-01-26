# Feature Specification: Terraform Enterprise on IBM Cloud (HVD)

**Feature Branch**: `001-tfe-ibm-deployment`
**Created**: 2025-01-26
**Updated**: 2026-01-26 (clarifications added)
**Status**: Draft
**Input**: User description: "Terraform Enterprise deployment on IBM Cloud, based on the patterns and standards from the terraform-aws-terraform-enterprise-hvd module"

## Design Clarifications

The following clarifications were gathered to refine the specification:

### Deployment Approach
- **Operational Mode**: Default to "external" (single-instance) mode for simplicity, but design all components (networking, load balancing, storage) to easily upgrade to "active-active" mode without significant reconfiguration. This provides a clear migration path as deployment needs mature.

### Sizing & Scale
- **Target Deployment Size**: Medium enterprise deployment (50-200 users, 100-500 workspaces, multiple teams). This sets reasonable defaults for:
  - VSI profiles: bx2-8x32 (8 vCPU, 32GB RAM)
  - PostgreSQL: 4 vCPU, 16GB RAM with high availability
  - Object Storage: Multi-region standard storage class
  - Redis (active-active): 12GB memory minimum

### Network Architecture
- **Endpoint Strategy**: Configurable architecture supporting both public and private endpoint patterns:
  - **Public Mode**: Internet-accessible load balancer with public endpoints
  - **Private Mode**: Private endpoints for all services, requires VPN/Direct Link
  - **Hybrid Mode**: Private backend services with public load balancer (recommended default)
  - Module variables control endpoint type for each service independently

### Security Baseline
- **Default Security Posture**: Enhanced security configuration including:
  - IBM Cloud Secrets Manager integration for all sensitive data (license, certificates, passwords)
  - IBM Cloud Key Protect for encryption key management (data at rest)
  - TLS 1.2+ for all encrypted communications (data in transit)
  - IBM Cloud Activity Tracker for audit logging
  - Security groups with least-privilege firewall rules
  - Option to upgrade to Hyper Protect Crypto Services for FIPS 140-2 Level 4 compliance

### Backup & Recovery
- **Approach**: Flexible backup strategy without prescriptive RPO/RTO targets:
  - PostgreSQL automated backups enabled (configurable retention 1-35 days)
  - Object Storage versioning enabled for artifact protection
  - Point-in-time recovery capability through database continuous backups
  - Users define their own recovery objectives based on business requirements

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Functional TFE Instance (Priority: P1)

Infrastructure engineers need to deploy a working Terraform Enterprise instance on IBM Cloud that can be accessed and configured immediately after deployment. This represents the core MVP - a single-region, operational TFE deployment with all essential services (compute, database, storage, load balancing) properly configured and connected.

**Why this priority**: This is the foundational capability - without a working deployment, no other features matter. Delivers immediate value by enabling teams to start using TFE on IBM Cloud.

**Independent Test**: Can be fully tested by running `terraform apply`, verifying the TFE URL is accessible via HTTPS, and successfully creating the initial admin user account. Delivers a complete, production-ready TFE instance.

**Acceptance Scenarios**:

1. **Given** valid IBM Cloud credentials and a VPC with subnets, **When** deploying the module with minimum required inputs, **Then** TFE application is accessible via the configured FQDN over HTTPS and health checks pass
2. **Given** a successful deployment, **When** navigating to the initial admin user creation URL, **Then** the admin account can be created and used to log into TFE
3. **Given** TFE is deployed, **When** creating a workspace and running a Terraform plan, **Then** the plan executes successfully using TFE's compute resources
4. **Given** multiple deployment attempts, **When** resources already exist, **Then** Terraform detects existing resources and handles them appropriately without errors

---

### User Story 2 - Configure High Availability Deployment (Priority: P2)

Operations teams need to deploy TFE in active-active mode with multiple instances across availability zones to ensure continuous service availability during maintenance windows or zone failures. This includes autoscaling capabilities and proper load balancer health checking.

**Why this priority**: Essential for production environments requiring high uptime SLAs. Builds on P1 by adding resilience without changing core functionality.

**Independent Test**: Can be tested independently by setting `tfe_operational_mode = "active-active"` and `asg_instance_count > 1`, then verifying multiple VSI instances are running, load balancer distributes traffic across them, and service remains available when one instance is terminated.

**Acceptance Scenarios**:

1. **Given** active-active mode configuration, **When** deploying the module, **Then** multiple TFE instances are created across different availability zones
2. **Given** multiple TFE instances running, **When** one instance becomes unhealthy, **Then** the load balancer stops routing traffic to it and autoscaling group replaces it automatically
3. **Given** concurrent Terraform runs, **When** submitted to TFE, **Then** workload is distributed across available instances without conflict
4. **Given** database read replicas configured, **When** performing read-heavy operations, **Then** read queries are distributed to replica instances

---

### User Story 3 - Manage Secrets and Certificates Securely (Priority: P3)

Security teams need all sensitive data (TFE license, database passwords, TLS certificates, encryption keys) stored in IBM Cloud Secrets Manager and injected into TFE at runtime, with no secrets exposed in Terraform state or logs.

**Why this priority**: Critical for security compliance but can be implemented after basic deployment works. Enhances P1 without changing its core deployment logic.

**Independent Test**: Can be tested by verifying all secret ARNs are passed as variables, checking Terraform state contains only ARN references (not secret values), and confirming TFE application successfully retrieves and uses secrets from Secrets Manager during startup.

**Acceptance Scenarios**:

1. **Given** secrets stored in IBM Cloud Secrets Manager, **When** deploying TFE, **Then** all secrets are retrieved dynamically and no plaintext secrets appear in Terraform state
2. **Given** TLS certificate expiration approaching, **When** certificate is rotated in Secrets Manager, **Then** TFE instances automatically retrieve and use the new certificate after restart
3. **Given** database password rotation, **When** password is updated in Secrets Manager, **Then** TFE connection pool re-authenticates without manual intervention
4. **Given** audit requirements, **When** secrets are accessed, **Then** all access events are logged in IBM Cloud Activity Tracker

---

### User Story 4 - Integrate with IBM Cloud Monitoring and Logging (Priority: P4)

Platform teams need TFE application logs forwarded to IBM Log Analysis and metrics sent to IBM Cloud Monitoring to enable centralized observability, troubleshooting, and alerting across their cloud infrastructure.

**Why this priority**: Important for operations but not required for initial functionality. Can be added after deployment works.

**Independent Test**: Can be tested by configuring log forwarding destinations, generating TFE activity (workspace creation, plan execution), and verifying logs appear in Log Analysis and metrics appear in Monitoring dashboards.

**Acceptance Scenarios**:

1. **Given** IBM Log Analysis integration configured, **When** TFE performs operations, **Then** application logs appear in Log Analysis with proper metadata
2. **Given** IBM Cloud Monitoring integration configured, **When** TFE runs workloads, **Then** resource utilization metrics (CPU, memory, disk) are visible in Monitoring dashboards
3. **Given** custom Fluent Bit configuration, **When** specified by user, **Then** logs are forwarded to the custom destination in the specified format
4. **Given** alert thresholds defined, **When** metrics exceed thresholds, **Then** alerts are triggered through IBM Cloud Monitoring

---

### User Story 5 - Customize Deployment for Air-Gapped Environments (Priority: P5)

Enterprise security teams need to deploy TFE in air-gapped or restricted network environments using private endpoints, custom container registries, and HTTP proxies without any public internet connectivity.

**Why this priority**: Required only for highly regulated environments. Most users deploy with internet access, making this an advanced customization.

**Independent Test**: Can be tested by deploying with all public endpoints disabled, custom container registry configured, and HTTP proxy settings enabled, then verifying TFE operates normally without any outbound internet connections.

**Acceptance Scenarios**:

1. **Given** private endpoints configured for all IBM Cloud services, **When** deploying TFE, **Then** all service communication occurs through private network without internet egress
2. **Given** custom container registry specified, **When** TFE starts up, **Then** the TFE application image is pulled from the custom registry using provided credentials
3. **Given** HTTP proxy configured, **When** TFE makes outbound requests, **Then** all traffic routes through the proxy and no direct internet connections occur
4. **Given** VCS integration in air-gapped mode, **When** connecting to on-premises VCS, **Then** TFE successfully authenticates and retrieves repository content over private network

---

### Edge Cases

- What happens when IBM Cloud region experiences a service disruption affecting VPC, Database, or Object Storage?
- How does the system handle mismatched secret ARN references (pointing to non-existent secrets)?
- What occurs when autoscaling group attempts to launch instances but has reached IBM Cloud quota limits?
- How does TFE behave when the PostgreSQL database connection is interrupted mid-transaction?
- What happens when Object Storage bucket exceeds capacity limits or experiences throttling?
- How does the module handle Terraform state corruption or concurrent modification conflicts?
- What occurs when TLS certificate in Secrets Manager expires but hasn't been rotated?
- How does load balancer respond when all backend TFE instances become unhealthy simultaneously?
- What happens during database failover from primary to replica during active Terraform runs?
- How does the system handle conflicting module configuration (e.g., active-active mode with single instance count)?

## Requirements *(mandatory)*

### Functional Requirements

#### Core Deployment

- **FR-001**: Module MUST create an IBM Cloud VPC infrastructure deployment of Terraform Enterprise with all required supporting services
- **FR-002**: Module MUST support both "external" (single instance) and "active-active" (multi-instance) operational modes
- **FR-003**: Module MUST provision Virtual Server Instances (VSIs) running either Docker or Podman container runtime
- **FR-004**: Module MUST configure all networking components including VPC, subnets, security groups, and load balancers
- **FR-005**: Module MUST accept an existing VPC ID and subnet IDs rather than creating new networking infrastructure

#### Compute Resources

- **FR-006**: Module MUST provision IBM Cloud Virtual Server Instances with configurable instance profiles (e.g., bx2-4x16, bx2-8x32)
- **FR-007**: Module MUST support custom VSI images while defaulting to Ubuntu, RHEL, CentOS, or Rocky Linux base images
- **FR-008**: Module MUST create an instance group (autoscaling group) for managing TFE VSI lifecycle
- **FR-009**: Module MUST support SSH key pairs for VSI access
- **FR-010**: Module MUST inject user data (cloud-init) scripts to bootstrap TFE installation on VSI startup
- **FR-011**: Module MUST configure block storage volumes with customizable size, IOPS, and encryption settings
- **FR-012**: Module MUST support custom TFE startup script templates for advanced deployment scenarios

#### Database Services

- **FR-013**: Module MUST provision IBM Cloud Databases for PostgreSQL (version 14 or higher) as the TFE database backend
- **FR-014**: Module MUST support configurable database instance sizes (compute and memory profiles)
- **FR-015**: Module MUST enable automated database backups with configurable retention periods (1-35 days recommended)
- **FR-016**: Module MUST support database encryption using IBM Cloud Key Protect or Hyper Protect Crypto Services
- **FR-017**: Module MUST allow configuration of PostgreSQL database parameters for TFE optimization
- **FR-018**: Module MUST support high availability database configurations with replica instances
- **FR-019**: Module MUST place database instances in dedicated database subnets separate from compute subnets

#### Object Storage

- **FR-020**: Module MUST provision IBM Cloud Object Storage bucket for TFE object/blob storage
- **FR-021**: Module MUST configure Object Storage bucket with private endpoint access
- **FR-022**: Module MUST enable Object Storage encryption using customer-managed keys via Key Protect
- **FR-023**: Module MUST configure Object Storage lifecycle policies for data management
- **FR-024**: Module MUST support Cross-Region Replication for Object Storage disaster recovery scenarios
- **FR-025**: Module MUST allow either instance profile-based authentication or access key-based authentication to Object Storage

#### Caching (Redis)

- **FR-026**: Module MUST provision IBM Cloud Databases for Redis (version 7.x) when operational mode is "active-active"
- **FR-027**: Module MUST support configurable Redis memory sizes (minimum 12GB recommended for production)
- **FR-028**: Module MUST enable Redis encryption in-transit and at-rest
- **FR-029**: Module MUST support Redis replica configuration for high availability
- **FR-030**: Module MUST store Redis authentication password in IBM Cloud Secrets Manager

#### Load Balancing

- **FR-031**: Module MUST provision IBM Cloud Application Load Balancer (ALB) or Network Load Balancer (NLB) for TFE traffic distribution
- **FR-032**: Module MUST configure load balancer listeners for HTTPS (port 443) traffic
- **FR-033**: Module MUST support both public (internet-facing) and private (internal) load balancer configurations
- **FR-034**: Module MUST configure load balancer health checks targeting TFE health check endpoint
- **FR-035**: Module MUST support session persistence (sticky sessions) for TFE application continuity
- **FR-036**: Module MUST distribute traffic across multiple availability zones for high availability

#### DNS and Networking

- **FR-037**: Module MUST accept a fully qualified domain name (FQDN) for TFE access
- **FR-038**: Module MUST optionally create IBM Cloud DNS (DNS Services) records pointing to the load balancer
- **FR-039**: Module MUST configure security groups allowing HTTPS (443) ingress from specified CIDR ranges
- **FR-040**: Module MUST configure security groups allowing egress to database, Redis, and Object Storage services
- **FR-041**: Module MUST support optional SSH (port 22) ingress from bastion/management CIDR ranges
- **FR-042**: Module MUST support HTTP proxy configuration for outbound internet connectivity
- **FR-043**: Module MUST support VPN or Direct Link connectivity for hybrid cloud scenarios

#### Security and Secrets Management

- **FR-044**: Module MUST retrieve TFE license file from IBM Cloud Secrets Manager at deployment time
- **FR-045**: Module MUST retrieve TLS certificates and private keys from IBM Cloud Secrets Manager (PEM format, base64-encoded)
- **FR-046**: Module MUST retrieve TFE encryption password from IBM Cloud Secrets Manager
- **FR-047**: Module MUST retrieve database credentials from IBM Cloud Secrets Manager
- **FR-048**: Module MUST retrieve Redis password from IBM Cloud Secrets Manager
- **FR-049**: Module MUST support custom CA bundles from Secrets Manager for private certificate authorities
- **FR-050**: Module MUST configure IAM policies granting VSI instances least-privilege access to required cloud services
- **FR-051**: Module MUST support encryption of all data at rest using IBM Cloud Key Protect or Hyper Protect Crypto Services
- **FR-052**: Module MUST enforce TLS 1.2 or higher for all encrypted communications

#### Logging and Monitoring

- **FR-053**: Module MUST support log forwarding to IBM Log Analysis
- **FR-054**: Module MUST support log forwarding to IBM Cloud Object Storage for long-term retention
- **FR-055**: Module MUST support custom Fluent Bit configurations for alternative log destinations
- **FR-056**: Module MUST enable IBM Cloud Monitoring integration for infrastructure metrics
- **FR-057**: Module MUST expose TFE metrics endpoint (port 9090 HTTP or 9091 HTTPS) with optional CIDR restrictions

#### TFE Configuration

- **FR-058**: Module MUST configure TFE operational mode ("external" or "active-active")
- **FR-059**: Module MUST configure TFE capacity settings (concurrency, CPU, memory limits)
- **FR-060**: Module MUST support custom TFE runtime configuration via environment variables
- **FR-061**: Module MUST support custom container image registry for TFE application image
- **FR-062**: Module MUST support TFE version pinning via image tag specification
- **FR-063**: Module MUST configure TFE run pipeline settings (Docker or Podman drivers)

#### Module Interface

- **FR-064**: Module MUST accept all required configuration via Terraform input variables following HashiCorp naming conventions
- **FR-065**: Module MUST output critical information including TFE URL, load balancer DNS name, database endpoint, and Object Storage bucket name
- **FR-066**: Module MUST use a modular file structure separating concerns (compute, database, storage, networking, IAM, etc.)
- **FR-067**: Module MUST include comprehensive variable validation to catch configuration errors early
- **FR-068**: Module MUST provide sensible defaults for optional variables while requiring explicit values for critical settings
- **FR-069**: Module MUST support common resource tagging for cost allocation and governance
- **FR-070**: Module MUST be compatible with Terraform versions 1.9 and higher
- **FR-071**: Module MUST use IBM Cloud Terraform Provider version 1.70.0 or higher
- **FR-072**: Module MUST utilize the variable naming convention established in the hashicorp/terraform-aws-terraform-enterprise-hvd module.

### Key Entities

- **TFE Instance (VSI)**: IBM Cloud Virtual Server Instance running containerized Terraform Enterprise application, with assigned security groups, block storage, and cloud-init configuration
- **Database Cluster**: IBM Cloud Databases for PostgreSQL cluster with primary and optional replica instances, configured with specific memory/compute profiles and backup policies
- **Object Storage Bucket**: IBM Cloud Object Storage bucket storing TFE artifacts, state files, and run data, with encryption and access policies
- **Redis Cluster**: IBM Cloud Databases for Redis instance providing distributed caching and locking for active-active TFE deployments
- **Load Balancer**: IBM Cloud ALB or NLB distributing traffic to TFE instances, with health checks and SSL termination configuration
- **VPC Network**: IBM Cloud Virtual Private Cloud containing all TFE resources, with subnets segmented by function (compute, database, load balancer)
- **Security Group**: IBM Cloud Security Group defining ingress and egress firewall rules for each resource type
- **Secrets**: Sensitive configuration values (license, certificates, passwords) stored in IBM Cloud Secrets Manager and referenced by ARN
- **IAM Policies**: IBM Cloud IAM policies granting service-to-service permissions (VSI to Object Storage, VSI to Secrets Manager, etc.)
- **Instance Group**: IBM Cloud Instance Group managing VSI lifecycle, health checks, and autoscaling behavior

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Infrastructure teams can deploy a functional TFE instance from module source to accessible application in under 30 minutes
- **SC-002**: Deployed TFE system successfully handles 100 concurrent Terraform plan operations without performance degradation
- **SC-003**: System maintains 99.9% uptime during business hours with active-active configuration across multiple availability zones
- **SC-004**: All secret values are retrieved from Secrets Manager with zero plaintext secrets exposed in Terraform state files
- **SC-005**: TFE application health check endpoint returns healthy status within 10 minutes of VSI instance launch
- **SC-006**: Database connections recover automatically within 60 seconds following a database failover event
- **SC-007**: Users can successfully create TFE workspaces and execute Terraform runs within 5 minutes of initial admin account creation
- **SC-008**: Module deployment completes successfully on first `terraform apply` with valid configuration (no manual intervention required)
- **SC-009**: All TFE application logs appear in configured log destination within 2 minutes of log generation
- **SC-010**: System scales from single instance to active-active mode through configuration change and `terraform apply` without data loss
- **SC-011**: 90% of module configuration errors are caught by variable validation before infrastructure provisioning begins
- **SC-012**: Module successfully deploys in multiple IBM Cloud regions (us-south, us-east, eu-de) without code changes

## Architecture Overview *(optional)*

### Service Mapping: AWS to IBM Cloud

This module replicates the architecture of `terraform-aws-terraform-enterprise-hvd` using IBM Cloud equivalents:

| AWS Service                      | IBM Cloud Service                                 | Purpose                                          |
| -------------------------------- | ------------------------------------------------- | ------------------------------------------------ |
| EC2 Instances                    | Virtual Server Instances (VSI)                    | Compute resources running TFE containers         |
| Auto Scaling Groups              | Instance Groups                                   | Manage VSI lifecycle and scaling                 |
| RDS Aurora PostgreSQL            | IBM Cloud Databases for PostgreSQL                | TFE metadata and application database            |
| ElastiCache Redis                | IBM Cloud Databases for Redis                     | Distributed caching and locking (active-active)  |
| S3                               | IBM Cloud Object Storage                          | TFE artifact and state storage                   |
| Application Load Balancer (ALB)  | IBM Cloud Application Load Balancer               | Layer 7 load balancing with SSL termination      |
| Network Load Balancer (NLB)      | IBM Cloud Network Load Balancer                   | Layer 4 load balancing for performance           |
| Secrets Manager                  | IBM Cloud Secrets Manager                         | Secure storage for certificates, passwords       |
| KMS                              | IBM Cloud Key Protect / Hyper Protect Crypto     | Encryption key management                        |
| CloudWatch Logs                  | IBM Log Analysis                                  | Centralized log aggregation                      |
| CloudWatch Metrics               | IBM Cloud Monitoring                              | Infrastructure and application metrics           |
| VPC                              | IBM Cloud VPC                                     | Network isolation and segmentation               |
| Security Groups                  | Security Groups                                   | Instance-level firewall rules                    |
| Route 53                         | IBM Cloud DNS Services                            | DNS record management                            |
| IAM Roles/Policies               | IAM Policies / Service IDs                        | Service-to-service authentication                |
| EBS Volumes                      | Block Storage Volumes                             | Persistent storage for VSI instances             |

### Network Architecture

```
                                    ┌─────────────────┐
                                    │   IBM Cloud     │
                                    │   DNS Services  │
                                    │  (tfe.example)  │
                                    └────────┬────────┘
                                             │
                                             ▼
┌────────────────────────────────────────────────────────────────┐
│                         VPC Network                             │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              Load Balancer Subnets (Public/Private)      │  │
│  │   ┌──────────────────────────────────────────────┐      │  │
│  │   │  Application/Network Load Balancer           │      │  │
│  │   │  - HTTPS Listener (443)                      │      │  │
│  │   │  - Health Checks                              │      │  │
│  │   │  - SSL Termination                            │      │  │
│  │   └───────────────┬──────────────────────────────┘      │  │
│  └───────────────────┼──────────────────────────────────────┘  │
│                      │                                          │
│  ┌───────────────────┼──────────────────────────────────────┐  │
│  │              Compute Subnets (Private)                   │  │
│  │                   ▼                                       │  │
│  │   ┌─────────────────────────────────────────┐            │  │
│  │   │    TFE Instance Group (Autoscaling)     │            │  │
│  │   │  ┌─────────┐  ┌─────────┐  ┌─────────┐ │            │  │
│  │   │  │ TFE VSI │  │ TFE VSI │  │ TFE VSI │ │            │  │
│  │   │  │  AZ-1   │  │  AZ-2   │  │  AZ-3   │ │            │  │
│  │   │  └─────────┘  └─────────┘  └─────────┘ │            │  │
│  │   └───────┬──────────────┬──────────────────┘            │  │
│  └───────────┼──────────────┼──────────────────────────────┘  │
│              │              │                                  │
│  ┌───────────┼──────────────┼──────────────────────────────┐  │
│  │      Database Subnets (Private)                          │  │
│  │           ▼              ▼                                │  │
│  │   ┌─────────────────────────────────┐                    │  │
│  │   │  PostgreSQL Cluster             │                    │  │
│  │   │  ┌─────────┐    ┌──────────┐   │                    │  │
│  │   │  │ Primary │◄──►│ Replica  │   │                    │  │
│  │   │  └─────────┘    └──────────┘   │                    │  │
│  │   └─────────────────────────────────┘                    │  │
│  │           ▼                                               │  │
│  │   ┌─────────────────────────────────┐                    │  │
│  │   │  Redis Cluster (active-active)  │                    │  │
│  │   │  ┌─────────┐    ┌──────────┐   │                    │  │
│  │   │  │ Primary │◄──►│ Replica  │   │                    │  │
│  │   │  └─────────┘    └──────────┘   │                    │  │
│  │   └─────────────────────────────────┘                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                         │              │
         ┌───────────────┴──────────────┴────────────────┐
         ▼                                                ▼
┌─────────────────────┐                    ┌──────────────────────┐
│  Object Storage     │                    │  Secrets Manager     │
│  - TFE Artifacts    │                    │  - TLS Certificates  │
│  - State Files      │                    │  - Database Password │
│  - Run Logs         │                    │  - Redis Password    │
│  - Encrypted at Rest│                    │  - TFE License       │
└─────────────────────┘                    │  - Encryption Key    │
                                           └──────────────────────┘
```

### Module Structure

Following the AWS HVD module pattern, the IBM module will use this file organization:

```
terraform-ibm-terraform-enterprise/
├── README.md                  # Comprehensive usage documentation
├── versions.tf                # Provider version constraints
├── variables.tf               # All input variable definitions
├── outputs.tf                 # Module outputs
├── data.tf                    # Data source lookups (images, regions, etc.)
├── compute.tf                 # VSI instances, instance groups, user data
├── database.tf                # PostgreSQL database cluster configuration
├── redis.tf                   # Redis cluster configuration (active-active)
├── storage.tf                 # Object Storage bucket and policies
├── load_balancer.tf           # ALB/NLB and listeners
├── networking.tf              # Security groups and network ACLs
├── iam.tf                     # IAM policies and service IDs
├── dns.tf                     # IBM Cloud DNS records (optional)
├── locals.tf                  # Local value computations
├── templates/
│   ├── user_data.sh.tpl      # Cloud-init script template
│   ├── fluent-bit-logdna.conf.tpl      # Log forwarding config
│   ├── fluent-bit-cos.conf.tpl         # COS log forwarding config
│   └── docker-compose.yaml.tpl         # TFE container composition
├── examples/
│   ├── main/                  # Complete deployment example
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars.example
│   │   └── backend.tf
│   └── air-gapped/            # Air-gapped deployment example
└── docs/
    ├── deployment-customizations.md
    ├── tfe-version-upgrades.md
    ├── tfe-cert-rotation.md
    └── tfe-bootstrap-secrets.md
```

## Dependencies and Assumptions *(optional)*

### Dependencies

- **IBM Cloud Account**: Active IBM Cloud account with appropriate resource quotas
- **IBM Cloud CLI**: Version 2.0 or higher for manual operations and troubleshooting
- **Terraform CLI**: Version 1.9.0 or higher on deployment workstation
- **IBM Cloud Terraform Provider**: Version 1.70.0 or higher
- **TFE License**: Valid Terraform Enterprise license file (`.hclic` format)
- **Existing VPC Infrastructure**: Pre-configured VPC with subnets across multiple availability zones
- **TLS Certificates**: Valid TLS certificate matching TFE FQDN, issued by trusted CA
- **IBM Cloud Secrets Manager**: Pre-provisioned Secrets Manager instance for bootstrap secrets
- **IAM Permissions**: Service ID or user with permissions to create VPC resources, databases, storage, and IAM policies

### Assumptions

- **Network Configuration**: Users have already planned and created their VPC network topology with appropriate subnet segmentation
- **Secret Preparation**: All bootstrap secrets (license, certificates, passwords) are created in Secrets Manager before module deployment
- **DNS Management**: Users will manage DNS records externally if not using IBM Cloud DNS Services integration
- **Operating System**: Default to Ubuntu 22.04 LTS for VSI base image unless user specifies custom image
- **Container Runtime**: Default to Docker runtime unless Podman is explicitly specified
- **TFE Version**: Default to latest stable TFE release unless specific version tag provided
- **Operational Mode**: Default to "external" (single instance) mode for simplicity, with active-active as opt-in
- **Load Balancer Type**: Default to Network Load Balancer for performance, with ALB as alternative option
- **Database Size**: Assume production deployments require minimum 4vCPU, 16GB memory for PostgreSQL
- **Redis Requirement**: Redis is only provisioned when active-active mode is enabled
- **Backup Retention**: Assume 35-day backup retention as sensible default for compliance
- **Log Forwarding**: Disabled by default, enabled when user provides log destination configuration
- **Encryption**: All encryption uses IBM Cloud Key Protect by default; Hyper Protect Crypto Services requires explicit configuration
- **Internet Connectivity**: Assume internet access for container image pulls unless air-gapped configuration specified
- **Certificate Format**: All certificates and keys must be PEM format, base64-encoded as strings in Secrets Manager
- **Region Support**: Module should work in any IBM Cloud region supporting VPC and required database services

## Constraints *(optional)*

### Technical Constraints

- **IBM Cloud Provider Limitations**: Some AWS-specific features may not have direct IBM Cloud equivalents (e.g., certain autoscaling policies, specific load balancer routing capabilities)
- **Database Version Constraints**: IBM Cloud Databases for PostgreSQL must be version 14 or higher to meet TFE requirements
- **Redis Version Requirements**: Active-active mode requires Redis 7.x with specific configuration parameters
- **Container Runtime Support**: Limited to Docker and Podman; other container runtimes not supported by TFE
- **Instance Profile Limitations**: Not all VSI profiles may meet TFE's minimum compute requirements (4vCPU, 16GB RAM)
- **Regional Service Availability**: Some IBM Cloud services (like Databases for Redis) may not be available in all regions
- **API Rate Limits**: IBM Cloud API rate limits may affect deployment speed for large-scale configurations
- **Quota Limits**: Default IBM Cloud quotas may restrict number of VSIs, storage volumes, or other resources
- **TFE Container Image Access**: Requires either internet access to HashiCorp container registry or custom container registry setup

### Operational Constraints

- **Deployment Time**: Full deployment typically takes 20-30 minutes due to database provisioning time
- **Downtime Requirements**: Certain configuration changes (e.g., database size changes) may require scheduled downtime
- **State File Management**: Terraform state file contains infrastructure references; must be managed securely and backed up
- **Module Version Compatibility**: Breaking changes between module versions may require migration procedures
- **IBM Cloud Service Dependencies**: Outages in IBM Cloud platform services directly impact TFE availability

### Security Constraints

- **Certificate Management**: TLS certificates must be valid and unexpired; rotation requires manual update in Secrets Manager
- **Secret Rotation**: Database and Redis password rotation requires coordinated updates across Secrets Manager and application
- **IAM Permission Scope**: Module requires broad IAM permissions during initial deployment; follows principle of least privilege for runtime operations
- **Network Segmentation**: Deployment assumes proper network segmentation; module does not create VPC or subnets to avoid over-privileged access
- **Compliance Requirements**: Users in regulated industries must verify module configuration meets specific compliance standards (HIPAA, PCI-DSS, etc.)

## Out of Scope *(optional)*

The following capabilities are explicitly **not included** in this feature:

### Infrastructure Not Managed

- **VPC Creation**: Module does not create the base VPC; users must provide existing VPC ID
- **Subnet Creation**: Module does not create subnets; users must provide existing subnet IDs
- **VPN/Direct Link Setup**: Hybrid connectivity configuration is user's responsibility
- **DNS Zone Management**: Module does not create DNS zones; only creates records in existing zones
- **Certificate Issuance**: Module does not generate or issue TLS certificates; users must provide valid certificates
- **Secrets Manager Provisioning**: Module does not create Secrets Manager instance; must exist beforehand

### Advanced TFE Features

- **Multi-Region Replication**: Initial version focuses on single-region deployment; cross-region disaster recovery is future enhancement
- **Custom TFE Modules**: Pre-installed custom Terraform modules or provider plugins not included
- **SAML/SSO Configuration**: TFE identity provider integration is configured post-deployment via TFE UI
- **VCS Integration**: Version control system integration is configured through TFE application settings, not module
- **Policy-as-Code (Sentinel)**: Sentinel policies managed within TFE application, not module deployment
- **Cost Estimation Integration**: Cost estimation service configuration done through TFE settings

### Operational Tooling

- **Backup/Restore Automation**: Module enables database backups but does not provide restore procedures or automation
- **Disaster Recovery Runbooks**: Documentation provided but automated DR failover not included
- **Monitoring Dashboards**: Module sends metrics/logs to IBM Cloud services but does not create custom dashboards
- **Alert Configuration**: Module exposes metrics but does not pre-configure alert rules or notification channels
- **Automated Patching**: TFE version upgrades are manual operations triggered by updating image tag variable

### Migration Tools

- **Data Migration from Other Platforms**: No automated migration from other TFE deployments (AWS, Azure, on-premises)
- **Import Existing Resources**: Module assumes greenfield deployment; importing existing IBM Cloud resources not supported
- **Legacy TFE Version Support**: Module targets TFE FDO architecture (v202201+); older PTFE versions not supported

### Testing and Validation

- **Automated Testing Framework**: Module does not include automated test suite (unit tests, integration tests)
- **Performance Benchmarking Tools**: No built-in performance testing or capacity planning tools
- **Compliance Scanning**: Module does not include automated compliance validation tools

## Implementation Phases *(optional)*

### Phase 1: MVP - Single Instance Deployment (Weeks 1-3)

**Goal**: Deploy functional single-instance TFE on IBM Cloud

**Deliverables**:
- Core module structure (variables.tf, outputs.tf, versions.tf)
- Compute resources (compute.tf): VSI instances with user data script
- Database (database.tf): PostgreSQL cluster configuration
- Storage (storage.tf): Object Storage bucket with encryption
- Load Balancer (load_balancer.tf): Basic NLB configuration
- Networking (networking.tf): Security groups for all components
- IAM (iam.tf): Service policies for VSI access to storage and secrets
- Templates: user_data.sh.tpl for TFE bootstrap
- Example: Complete working example in examples/main/
- Documentation: Basic README with deployment instructions

**Success Criteria**:
- `terraform apply` creates all resources without errors
- TFE application accessible via HTTPS
- Initial admin user creation successful
- Workspace creation and Terraform plan execution works

---

### Phase 2: High Availability and Scaling (Weeks 4-5)

**Goal**: Add active-active mode with Redis and autoscaling

**Deliverables**:
- Redis cluster configuration (redis.tf)
- Instance group autoscaling policies
- Multi-AZ deployment logic
- Load balancer health checks and session persistence
- Database read replica configuration
- Enhanced user data script for active-active coordination
- Updated examples showing HA configuration

**Success Criteria**:
- Multiple TFE instances run concurrently
- Load balancer distributes traffic across instances
- Redis provides distributed locking
- Service remains available during instance replacement

---

### Phase 3: Observability and Air-Gapped Support (Weeks 6-7)

**Goal**: Add comprehensive logging/monitoring and restricted network deployment

**Deliverables**:
- Log forwarding templates (fluent-bit-logdna.conf.tpl, fluent-bit-cos.conf.tpl)
- IBM Cloud Monitoring integration
- Metrics endpoint configuration
- HTTP proxy support in user data script
- Custom container registry configuration
- Private endpoint configuration for all services
- Air-gapped deployment example
- Enhanced documentation for observability setup

**Success Criteria**:
- Logs appear in IBM Log Analysis
- Metrics visible in IBM Cloud Monitoring
- TFE operates in air-gapped mode with no internet access
- Custom container registry successfully pulls TFE image

---

### Phase 4: Production Hardening and Documentation (Weeks 8-9)

**Goal**: Finalize production readiness and comprehensive documentation

**Deliverables**:
- DNS integration (dns.tf) for automated record creation
- Enhanced variable validation and error messages
- Comprehensive outputs for integration with other systems
- Security hardening (encryption at rest, TLS 1.3, etc.)
- Tagging strategy for cost allocation
- Complete documentation suite:
  - deployment-customizations.md
  - tfe-version-upgrades.md
  - tfe-cert-rotation.md
  - tfe-bootstrap-secrets.md
  - troubleshooting.md
- Production-ready examples with best practices

**Success Criteria**:
- Module passes security review
- All variables have clear descriptions and validation
- Documentation covers common scenarios and troubleshooting
- Module can be deployed in production without customization

---

### Phase 5: Advanced Features and Optimization (Weeks 10+)

**Goal**: Add advanced capabilities and optimize performance

**Deliverables**:
- Cross-region replication support
- Backup and restore procedures
- Performance tuning recommendations
- Advanced networking options (transit gateway, VPN)
- Multiple examples for different use cases
- Terraform Registry publication
- Community contribution guidelines

**Success Criteria**:
- Module supports disaster recovery scenarios
- Performance meets enterprise requirements
- Module published to Terraform Registry
- Active community adoption and feedback
