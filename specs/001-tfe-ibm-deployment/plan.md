# Implementation Plan: Terraform Enterprise on IBM Cloud (HVD)

**Branch**: `001-tfe-ibm-deployment` | **Date**: 2026-01-26 | **Spec**: [specs/001-tfe-ibm-deployment/spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-tfe-ibm-deployment/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy Terraform Enterprise on IBM Cloud VPC using infrastructure-as-code patterns based on the HashiCorp Validated Design (HVD) for AWS. The module provisions compute (VSI), database (PostgreSQL), storage (Object Storage), caching (Redis for active-active), load balancing, and networking resources with comprehensive security controls, secrets management, and observability integration. Supports both single-instance "external" mode and multi-instance "active-active" mode with flexible deployment options for public, private, and air-gapped environments.

## Technical Context

**Language/Version**: HCL (Terraform) 1.9+, Shell Script (Bash) for user-data templates  
**Primary Dependencies**: 
- IBM Cloud Terraform Provider v1.70.0+
- IBM Cloud services: VPC, Virtual Server Instances, Databases (PostgreSQL, Redis), Object Storage, Load Balancers, Secrets Manager, Key Protect
- Terraform Enterprise container image (Docker/Podman runtime)

**Storage**: 
- PostgreSQL 14+ (TFE application database, metadata)
- IBM Cloud Object Storage (TFE artifacts, state files, run logs)
- Redis 7.x (distributed caching and locking for active-active mode)
- Block Storage volumes (ephemeral VSI storage)

**Testing**: NEEDS CLARIFICATION (see Phase 0 research: integration testing strategy for Terraform modules)

**Target Platform**: 
- IBM Cloud VPC (multi-zone, multi-region capable)
- Ubuntu 22.04 LTS / RHEL 8+ / Rocky Linux 8+ (VSI base images)
- TFE FDO architecture (Flexible Deployment Options, v202201+)

**Project Type**: Single infrastructure-as-code module (Terraform root module with 14 component files)

**Performance Goals**: 
- Support 100 concurrent Terraform plan operations without degradation
- TFE health check passes within 10 minutes of VSI launch
- Database connection recovery within 60 seconds after failover
- Deployment completion under 30 minutes (full stack)

**Constraints**: 
- IBM Cloud API rate limits
- Regional service availability (some services not in all regions)
- VSI instance profile minimums (4vCPU, 16GB RAM for TFE)
- PostgreSQL version 14+ required
- Redis 7.x required for active-active mode
- No plaintext secrets in Terraform state
- TLS 1.2+ for all encrypted communications

**Scale/Scope**: 
- Target: Medium enterprise (50-200 users, 100-500 workspaces)
- Default sizing: VSI bx2-8x32 (8vCPU, 32GB), PostgreSQL 4vCPU/16GB, Redis 12GB
- 14 Terraform files following AWS HVD pattern
- 72 functional requirements across 9 service domains
- 5 deployment phases (P1-P5 aligned with user story priorities)

## Constitution Check (Post-Design)

*Re-evaluation after Phase 1 design completion.*

| Check | Status | Notes |
|-------|--------|-------|
| **Module Structure** | ✅ PASS | 14 Terraform files with clear separation: compute, database, storage, networking, IAM, etc. |
| **Input Validation** | ✅ PASS | 31 input variables with comprehensive validation rules (CRN format, CIDR blocks, cross-variable checks) |
| **Secrets Management** | ✅ PASS | 6 required secrets via Secrets Manager, zero plaintext in state, IAM policies enforced |
| **Idempotency** | ✅ PASS | Declarative Terraform model, all resources handle updates gracefully |
| **Testing Strategy** | ✅ PASS | Native Terraform test framework (.tftest.hcl), integration tests for basic/active-active/secrets scenarios |
| **Documentation** | ✅ PASS | Complete docs: research.md, data-model.md, 3 contracts, quickstart.md, planned troubleshooting guides |
| **Versioning** | ✅ PASS | Semantic versioning committed, provider constraints defined (Terraform 1.9+, IBM Provider 1.70+) |
| **Security Baseline** | ✅ PASS | TLS 1.2+, encryption at rest (Key Protect), least privilege IAM, security groups with minimal ingress |
| **Observability** | ✅ PASS | Optional log forwarding (LogDNA/COS), monitoring integration, metrics endpoint, Activity Tracker |
| **Simplicity** | ✅ PASS | Single root module, defaults to simpler "external" mode, preset sizing (small/medium/large) |

**Overall Assessment**: ✅ **APPROVED** - Design adheres to Terraform best practices, no constitution violations detected.

**Design Quality**:
- Clear entity relationships (11 core entities with well-defined contracts)
- Service-specific patterns adapted from AWS HVD reference architecture
- Comprehensive variable validation catches errors before expensive provisioning
- Modular file structure enables maintainability without over-engineering

**Risk Mitigation**:
- Database provisioning time (15-20 minutes) documented as IBM Cloud platform constraint
- Regional service availability validated (Redis not available in all regions)
- Testing strategy balances coverage with cost (manual approval gate for integration tests)

## Project Structure

### Documentation (this feature)

```text
specs/001-tfe-ibm-deployment/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── module-interface.md        # Terraform variables/outputs contract
│   ├── ibm-cloud-services.md      # IBM Cloud service dependencies
│   └── secrets-manager-schema.md  # Required secrets structure
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Terraform Module Structure (Single Root Module)
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
│   ├── user_data.sh.tpl               # Cloud-init script template
│   ├── fluent-bit-logdna.conf.tpl     # Log forwarding config
│   ├── fluent-bit-cos.conf.tpl        # COS log forwarding config
│   └── docker-compose.yaml.tpl        # TFE container composition
├── examples/
│   ├── basic/                   # Minimal single-instance deployment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars.example
│   │   └── README.md
│   ├── active-active/           # High availability deployment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars.example
│   │   └── README.md
│   └── air-gapped/              # Air-gapped deployment example
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars.example
│       └── README.md
├── docs/
│   ├── deployment-customizations.md
│   ├── tfe-version-upgrades.md
│   ├── tfe-cert-rotation.md
│   ├── tfe-bootstrap-secrets.md
│   └── troubleshooting.md
└── tests/
    ├── basic_deployment.tftest.hcl      # Basic single-instance deployment test
    ├── active_active.tftest.hcl         # High availability multi-instance test
    ├── secrets_integration.tftest.hcl   # Secrets Manager integration test
    └── fixtures/                        # Test fixtures and helper modules
        ├── setup/                       # Setup modules for test prerequisites
        └── test.tfvars                  # Common test variables
```

**Structure Decision**: Single root module pattern following HashiCorp AWS HVD module conventions. This is standard practice for Terraform modules - all resources are defined at the root level with logical separation across 14 .tf files. No submodules needed since all resources are tightly coupled and share lifecycle. Examples directory provides three usage patterns (basic, HA, air-gapped) demonstrating different deployment scenarios.

## Complexity Tracking

> **No violations detected - Section not applicable**

All architectural decisions align with standard Terraform module best practices. The module maintains simplicity by:
- Using single root module (no unnecessary submodule abstraction)
- Defaulting to simpler "external" mode (active-active is opt-in)
- Following established AWS HVD patterns (well-understood by community)
- Clear separation of concerns across 14 files without over-engineering

---

## Design Decisions

### Architecture Patterns

**Decision 1: Single Root Module vs. Nested Modules**
- **Choice**: Single root module with 14 `.tf` files
- **Rationale**: All TFE resources share lifecycle and are tightly coupled. Nested modules add complexity without providing reusability benefits. AWS HVD reference uses single root module pattern.
- **Alternative Rejected**: Nested modules (compute/, database/, storage/) would require complex variable passing and state management.

**Decision 2: Operational Mode Flexibility**
- **Choice**: Default to "external" (single instance), support "active-active" as opt-in
- **Rationale**: 80% of deployments start simple (P1 user story prioritization). All components designed to support both modes without redesign.
- **Alternative Rejected**: Active-active only would force unnecessary complexity and cost for small deployments.

**Decision 3: IBM Cloud Service Equivalents**
- **Choice**: Map AWS services to IBM Cloud equivalents (EC2→VSI, RDS→ICD PostgreSQL, S3→COS)
- **Rationale**: Proven AWS HVD architecture translated to IBM Cloud platform. Users familiar with AWS can understand IBM Cloud deployment.
- **Alternative Rejected**: Design from scratch would miss HashiCorp's validated patterns.

### Variable Design

**Decision 4: Preset Deployment Sizes**
- **Choice**: Offer small/medium/large presets plus custom option
- **Rationale**: Users struggle with capacity planning. Preset sizes (tested configurations) reduce deployment errors. Custom option preserves flexibility.
- **Implementation**:
  ```hcl
  variable "deployment_size" {
    type    = string
    default = "medium"  # Balanced default
    validation {
      condition     = contains(["small", "medium", "large", "custom"], var.deployment_size)
      error_message = "Must be small, medium, large, or custom."
    }
  }
  ```

**Decision 5: Network Connectivity Modes**
- **Choice**: Support public/hybrid/private modes via single variable
- **Rationale**: Different organizations have different security postures. Hybrid mode (private backend, public LB) balances security and accessibility.
- **Alternative Rejected**: Public-only or private-only would not serve diverse deployment scenarios.

**Decision 6: Comprehensive Variable Validation**
- **Choice**: Validate CRN formats, CIDR blocks, cross-variable dependencies at plan time
- **Rationale**: Database provisioning takes 15-20 minutes. Early validation prevents costly failed deployments.
- **Example**:
  ```hcl
  validation {
    condition     = can(regex("^crn:v1:bluemix:public:secrets-manager:", var.tfe_license_secret_crn))
    error_message = "Must be valid Secrets Manager CRN."
  }
  ```

### Secrets Management

**Decision 7: Pre-Created Secrets Pattern**
- **Choice**: Require all secrets to exist in Secrets Manager before `terraform apply`
- **Rationale**: Avoids circular dependency (Terraform creates secrets → VSI reads secrets → depends on Terraform). Matches AWS HVD pattern.
- **Alternative Rejected**: Module creates secrets would require two-stage deployment or complex dependencies.

**Decision 8: IAM Authentication vs HMAC for Object Storage**
- **Choice**: Support both, default to IAM authentication
- **Rationale**: IAM provides automatic credential rotation and better security. HMAC offered for legacy compatibility.
- **Recommendation**: Users should use IAM unless they have specific HMAC requirement.

### High Availability

**Decision 9: Multi-AZ Deployment**
- **Choice**: Require subnets across multiple availability zones
- **Rationale**: Zone failures are common in cloud. Multi-AZ deployment provides resilience with minimal cost increase.
- **Validation**: Module validates subnets span multiple zones (warning, not error).

**Decision 10: Load Balancer Health Checks**
- **Choice**: Use TFE `/_health_check` endpoint with 60-second interval, 5 retries
- **Rationale**: TFE health check validates database/redis connectivity. 60-second interval balances responsiveness and cost.
- **Configuration**:
  ```hcl
  health_check {
    delay      = 60   # Balance between responsiveness and cost
    timeout    = 30
    max_retries = 5   # 5 minutes total before instance replaced
    url_path   = "/_health_check"
  }
  ```

### Security

**Decision 11: Encryption by Default**
- **Choice**: All data at rest encrypted via Key Protect (or HPCS for FIPS 140-2 Level 4)
- **Rationale**: Security best practice. IBM Cloud Databases always requires encryption. Object Storage encryption adds minimal cost.
- **Alternative Rejected**: Optional encryption would create insecure default configuration.

**Decision 12: TLS Termination at Load Balancer**
- **Choice**: Load balancer handles SSL termination, communicates with VSI via HTTPS
- **Rationale**: Centralized certificate management. TFE application still gets HTTPS traffic.
- **Alternative Rejected**: End-to-end TLS to VSI would require separate certificate management on each instance.

**Decision 13: Least Privilege Security Groups**
- **Choice**: Separate security groups for compute/LB/database with minimal rules
- **Rationale**: Defense in depth. Compromised component cannot access unrelated resources.
- **Example**: Database security group only accepts traffic from compute security group on port 5432.

### Observability

**Decision 14: Optional Observability Integration**
- **Choice**: Log forwarding and monitoring disabled by default, enabled via variables
- **Rationale**: Not all deployments need centralized observability (adds cost). Production deployments should enable.
- **Recommendation**: Enable for production, optional for dev/test environments.

**Decision 15: Fluent Bit for Log Forwarding**
- **Choice**: Use Fluent Bit agent on VSI to forward logs
- **Rationale**: Industry standard log forwarder. Supports multiple destinations (LogDNA, COS, custom).
- **Alternative Rejected**: Native IBM Cloud logging agent is LogDNA-specific, doesn't support custom destinations.

### Testing

**Decision 16: Native Terraform Test Framework**
- **Choice**: Use Terraform's built-in test language (.tftest.hcl files) for integration testing
- **Rationale**: Native Terraform testing (v1.6+) provides integration testing without external dependencies. Simpler than Go-based frameworks, supports both `plan` (unit-style) and `apply` (integration) commands, and allows mocking from v1.7+.
- **Cost Control**: Integration tests behind manual approval gate (expensive to run full deployment). Use `command = plan` for fast validation where possible.

**Decision 17: Test Coverage Strategy**
- **Choice**: Focus on critical paths (basic deployment, active-active, secrets retrieval) using Terraform test files
- **Rationale**: Full matrix testing (all regions × all sizes × all configurations) is cost-prohibitive.
- **Coverage**: 3 test files (.tftest.hcl) cover ~70% of module functionality with mix of plan and apply operations.

### Module Interface

**Decision 18: HashiCorp Naming Conventions**
- **Choice**: Follow AWS HVD variable naming (snake_case, prefixed by resource type)
- **Rationale**: Consistency with HashiCorp official modules. Users familiar with AWS module can migrate easily.
- **Examples**: `tfe_hostname`, `database_backup_retention_days`, `enable_log_forwarding`

**Decision 19: Semantic Versioning Commitment**
- **Choice**: Commit to semantic versioning for breaking changes
- **Rationale**: Module consumers need stable interface. Major version bumps signal breaking changes.
- **Policy**: 
  - Patch (1.0.x): Bug fixes only
  - Minor (1.x.0): New optional variables/outputs
  - Major (x.0.0): Rename variables, change defaults, remove outputs

---

## Implementation Phases

Following the 5-phase approach from feature spec:

### Phase 1: MVP - Single Instance Deployment (Weeks 1-3)
**Status**: Design complete (this document)
**Scope**: Basic "external" mode deployment with all core services

**Deliverables**:
1. Core Terraform files (14 files):
   - `versions.tf`, `variables.tf`, `outputs.tf`, `data.tf`, `locals.tf`
   - `compute.tf` (VSI, instance template, instance group)
   - `database.tf` (PostgreSQL cluster)
   - `storage.tf` (Object Storage bucket)
   - `load_balancer.tf` (NLB, listener, pool, health checks)
   - `networking.tf` (security groups, rules)
   - `iam.tf` (service authorization policies)
   - `dns.tf` (optional DNS records)
   - `redis.tf` (conditional, empty for external mode)

2. Templates:
   - `templates/user_data.sh.tpl` (VSI bootstrap script)
   - `templates/docker-compose.yaml.tpl` (TFE container composition)

3. Examples:
   - `examples/basic/` (minimal deployment example)

4. Documentation:
   - `README.md` (module usage)
   - `docs/tfe-bootstrap-secrets.md` (secret preparation guide)

**Acceptance Criteria** (US-1):
- [ ] `terraform apply` completes successfully
- [ ] TFE accessible via HTTPS
- [ ] Initial admin user creation works
- [ ] Workspace creation and Terraform plan execution successful

### Phase 2: High Availability (Weeks 4-5)
**Scope**: Active-active mode with Redis, autoscaling, multi-AZ

**Deliverables**:
1. Redis cluster implementation (`redis.tf` populated)
2. Conditional logic for active-active mode
3. Instance group autoscaling policies
4. Load balancer session persistence
5. Database read replica configuration
6. Multi-AZ VSI deployment
7. `examples/active-active/` example

**Acceptance Criteria** (US-2):
- [ ] Multiple TFE instances deployed across zones
- [ ] Load balancer distributes traffic
- [ ] Redis distributed locking works
- [ ] Service survives single instance termination

### Phase 3: Observability & Air-Gapped (Weeks 6-7)
**Scope**: Logging, monitoring, private endpoint support

**Deliverables**:
1. Fluent Bit log forwarding templates
2. IBM Cloud Monitoring integration
3. Metrics endpoint configuration
4. HTTP proxy support in user data script
5. Custom container registry configuration
6. Private endpoint configuration
7. `examples/air-gapped/` example
8. `docs/observability.md` documentation

**Acceptance Criteria** (US-4, US-5):
- [ ] Logs forwarded to LogDNA/COS
- [ ] Metrics visible in IBM Cloud Monitoring
- [ ] TFE operates in air-gapped mode (no internet)
- [ ] Custom container registry works

### Phase 4: Production Hardening (Weeks 8-9)
**Scope**: Security enhancements, validation, documentation

**Deliverables**:
1. Enhanced variable validation
2. Comprehensive error messages
3. DNS integration (`dns.tf` implementation)
4. Tagging strategy
5. Complete documentation suite:
   - `docs/deployment-customizations.md`
   - `docs/tfe-version-upgrades.md`
   - `docs/tfe-cert-rotation.md`
   - `docs/troubleshooting.md`
   - `docs/backup-and-recovery.md`
6. Production-ready examples with best practices

**Acceptance Criteria**:
- [ ] All 31 variables have validation rules
- [ ] Cross-variable dependencies validated
- [ ] Security review passed
- [ ] Documentation complete and reviewed

### Phase 5: Testing & CI/CD (Weeks 10-11)
**Scope**: Automated testing, GitHub Actions, Terraform Registry

**Deliverables**:
1. Terraform test suite (`tests/`)
   - `basic_deployment.tftest.hcl` (single instance with `command = apply`)
   - `active_active.tftest.hcl` (HA mode with multi-AZ validation)
   - `secrets_integration.tftest.hcl` (secrets retrieval validation)
   - `plan_validation.tftest.hcl` (fast validation with `command = plan`)
2. GitHub Actions workflows:
   - Validation (fmt, validate, lint)
   - `terraform test` execution (manual approval gate for apply tests)
3. Terraform Registry publication
4. CHANGELOG.md
5. CONTRIBUTING.md

**Acceptance Criteria**:
- [ ] `terraform test` passes in us-south and eu-de
- [ ] CI/CD pipeline validates all PRs
- [ ] Module published to Terraform Registry
- [ ] Community contribution guidelines established

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Database provisioning timeout** | Medium | High | Document 15-20 min expected time; increase Terraform timeout values |
| **Redis unavailable in target region** | Low | Medium | Validate service availability before deployment; document supported regions |
| **Secret CRN misconfiguration** | High | Medium | Comprehensive CRN format validation; clear error messages |
| **TLS certificate mismatch** | Medium | High | Document certificate requirements; provide validation script |
| **IBM Cloud API rate limits** | Low | Low | Module creates <50 resources; well under limits |
| **Quota exceeded** | Medium | High | Document quota requirements; provide quota check script |
| **Database scaling requires downtime** | High | Medium | Document scaling procedure; recommend scheduled maintenance window |
| **VSI user data script failure** | Medium | High | Comprehensive logging in user data; health checks detect failure |
| **Load balancer certificate expiration** | Medium | High | Document cert rotation procedure; recommend monitoring |
| **Integration test costs** | High | Low | Manual approval gate for tests; cleanup automation |

---

## Success Metrics

From feature spec SC-001 to SC-012:

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Deployment time** | < 30 minutes | Terraform apply duration |
| **Concurrent Terraform runs** | 100 without degradation | Load testing (not in module scope) |
| **System uptime** | 99.9% (active-active) | Monitoring (not in module scope) |
| **Secrets in state** | 0 plaintext secrets | Terraform state inspection |
| **Health check time** | < 10 minutes | VSI launch to healthy status |
| **Database failover recovery** | < 60 seconds | Manual failover testing |
| **Admin account creation** | < 5 minutes after deployment | Quickstart guide validation |
| **First-time deployment success** | 100% with valid config | Integration test pass rate |
| **Log forwarding latency** | < 2 minutes | Log timestamp analysis |
| **External to active-active upgrade** | No data loss | Upgrade testing |
| **Variable validation catch rate** | > 90% of config errors | Validation test suite |
| **Multi-region deployment** | us-south, us-east, eu-de | Integration tests in 3 regions |
