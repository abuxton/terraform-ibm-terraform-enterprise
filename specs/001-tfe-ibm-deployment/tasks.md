# Tasks: Terraform Enterprise on IBM Cloud (HVD)

**Input**: Design documents from `/specs/001-tfe-ibm-deployment/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Native Terraform test framework (.tftest.hcl files) as specified in research.md. Tests are included per the implementation plan.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story, aligned with the 5-phase implementation approach.

## Format: `- [ ] [ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

All paths are relative to repository root:
- Core Terraform files: `*.tf` files at root level
- Templates: `templates/` directory
- Examples: `examples/basic/`, `examples/active-active/`, `examples/air-gapped/`
- Tests: `tests/` directory with `.tftest.hcl` files
- Documentation: `docs/` directory

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Initialize Terraform module structure and configuration files

- [ ] T001 Create module structure following AWS HVD pattern (14 .tf files at root)
- [ ] T002 [P] Initialize versions.tf with Terraform 1.9+ and IBM Cloud Provider 1.70+ constraints
- [ ] T003 [P] Create .gitignore for Terraform artifacts (.terraform/, *.tfstate, *.tfvars)
- [ ] T004 [P] Create .terraform-docs.yml configuration for automated documentation
- [ ] T005 [P] Create .tflint.hcl with IBM Cloud provider plugin configuration
- [ ] T006 [P] Create templates/ directory structure for user data and config templates
- [ ] T007 [P] Create examples/ directory structure (basic/, active-active/, air-gapped/)
- [ ] T008 [P] Create tests/ directory structure with fixtures/ subdirectory
- [ ] T009 [P] Create docs/ directory for operational documentation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Terraform infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T010 Create locals.tf with common value computations (naming conventions, tags, conditional logic)
- [ ] T011 Create data.tf with IBM Cloud data sources (image lookup, region zones, service endpoints)
- [ ] T012 Create variables.tf foundation with core variables (resource_group_id, region, vpc_id, friendly_name_prefix)
- [ ] T013 Add deployment configuration variables to variables.tf (tfe_operational_mode, deployment_size, network_connectivity)
- [ ] T014 Add validation rules to variables.tf for deployment_size and tfe_operational_mode
- [ ] T015 Create outputs.tf foundation with core outputs structure (tfe_url, load_balancer_hostname)
- [ ] T016 Create networking.tf with security group resources (compute, load_balancer, database security groups)
- [ ] T017 Add security group rules to networking.tf (ingress/egress rules for HTTPS, database, Redis)
- [ ] T018 Create iam.tf with service authorization policies (VSI to Object Storage, VSI to Secrets Manager)
- [ ] T019 [P] Create README.md with module overview, provider requirements, and basic usage example
- [ ] T020 [P] Create templates/user_data.sh.tpl bootstrap script skeleton with TFE container setup

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Deploy Functional TFE Instance (Priority: P1) 🎯 MVP

**Goal**: Deploy a working single-instance TFE deployment with all essential services (compute, database, storage, load balancing) that can be accessed via HTTPS and configured immediately after deployment.

**Independent Test**: Run `terraform apply` with basic configuration, verify TFE URL is accessible via HTTPS, successfully create initial admin user account, and execute a Terraform plan in a test workspace.

### Implementation for User Story 1

#### Core Service Resources

- [ ] T021 [P] [US1] Create compute.tf with VSI instance resource and instance template
- [ ] T022 [P] [US1] Create database.tf with IBM Cloud Databases for PostgreSQL resource (single instance, 4vCPU/16GB)
- [ ] T023 [P] [US1] Create storage.tf with IBM Cloud Object Storage bucket resource and encryption configuration
- [ ] T024 [P] [US1] Create load_balancer.tf with Network Load Balancer resource and HTTPS listener (port 443)

#### Variables for User Story 1

- [ ] T025 [US1] Add compute variables to variables.tf (instance_profile, image_id, ssh_key_ids, subnet_ids)
- [ ] T026 [US1] Add database variables to variables.tf (database_version, member_cpu, member_memory, backup_retention_days)
- [ ] T027 [US1] Add storage variables to variables.tf (cos_bucket_name, cos_storage_class, kms_key_crn)
- [ ] T028 [US1] Add load balancer variables to variables.tf (lb_subnet_ids, tfe_hostname, tls_certificate_crn)
- [ ] T029 [US1] Add secrets variables to variables.tf (tfe_license_secret_crn, tfe_encryption_password_secret_crn, database_password_secret_crn)

#### Validation and Integration

- [ ] T030 [US1] Add CRN format validation to variables.tf for all secret_crn variables
- [ ] T031 [US1] Add CIDR validation to variables.tf for allowed_ingress_cidrs variable
- [ ] T032 [US1] Add cross-variable validation to variables.tf (deployment_size must be defined if custom sizing)
- [ ] T033 [US1] Update locals.tf with instance sizing logic (map deployment_size to instance profiles)
- [ ] T034 [US1] Complete templates/user_data.sh.tpl with TFE installation logic (Docker setup, environment variables, container startup)
- [ ] T035 [US1] Create templates/docker-compose.yaml.tpl for TFE container configuration
- [ ] T036 [US1] Add health check configuration to load_balancer.tf (/_health_check endpoint, 60s interval, 5 retries)
- [ ] T037 [US1] Add load balancer pool and pool member configuration to load_balancer.tf
- [ ] T038 [US1] Update compute.tf with user_data script integration (templatefile() function call)
- [ ] T039 [US1] Update iam.tf with Key Protect access policies for encryption at rest
- [ ] T040 [US1] Add database outputs to outputs.tf (database_endpoint, database_port, database_name)
- [ ] T041 [US1] Add storage outputs to outputs.tf (cos_bucket_name, cos_endpoint)
- [ ] T042 [US1] Add load balancer outputs to outputs.tf (lb_public_ip, lb_private_ip, lb_hostname)
- [ ] T043 [US1] Update README.md with US1 deployment example (minimum required variables)

#### Testing for User Story 1

- [ ] T044 [US1] Create tests/basic_deployment.tftest.hcl with test structure and provider configuration
- [ ] T045 [US1] Add setup_prerequisites run block to tests/basic_deployment.tftest.hcl
- [ ] T046 [US1] Add validate_plan run block to tests/basic_deployment.tftest.hcl (command = plan)
- [ ] T047 [US1] Add deploy_tfe run block to tests/basic_deployment.tftest.hcl (command = apply, assert TFE URL output)
- [ ] T048 [US1] Create tests/fixtures/setup/ helper module for test prerequisites (VPC, subnets, SSH key)
- [ ] T049 [US1] Create tests/fixtures/test.tfvars with common test variable values
- [ ] T050 [P] [US1] Create examples/basic/ directory with main.tf, variables.tf, outputs.tf
- [ ] T051 [P] [US1] Create examples/basic/terraform.tfvars.example with sample values
- [ ] T052 [P] [US1] Create examples/basic/README.md with deployment instructions
- [ ] T053 [P] [US1] Create docs/tfe-bootstrap-secrets.md with Secrets Manager setup guide

**Checkpoint**: At this point, User Story 1 should be fully functional - a working single-instance TFE deployment accessible via HTTPS with initial admin user creation capability.

---

## Phase 4: User Story 2 - Configure High Availability Deployment (Priority: P2)

**Goal**: Enable active-active mode with multiple TFE instances across availability zones, Redis caching, autoscaling, and load balancer health checking for continuous service availability.

**Independent Test**: Set `tfe_operational_mode = "active-active"` and `instance_count = 3`, verify multiple VSI instances running across zones, load balancer distributes traffic, Redis distributed locking works, and service remains available when one instance is terminated.

### Implementation for User Story 2

#### Redis and Active-Active Configuration

- [ ] T054 [P] [US2] Create redis.tf with IBM Cloud Databases for Redis resource (conditional on active-active mode)
- [ ] T055 [US2] Add Redis variables to variables.tf (redis_memory_mb, redis_version, redis_replica_count)
- [ ] T056 [US2] Add redis_password_secret_crn variable to variables.tf with CRN validation
- [ ] T057 [US2] Update locals.tf with Redis connection string logic (conditional on operational mode)

#### Instance Group and Autoscaling

- [ ] T058 [US2] Update compute.tf with instance group resource (replacing single instance)
- [ ] T059 [US2] Add instance_count variable to variables.tf (validation: 1 for external, >=2 for active-active)
- [ ] T060 [US2] Add autoscaling configuration to compute.tf (min/max instances, scaling policies)
- [ ] T061 [US2] Add asg_min_size and asg_max_size variables to variables.tf
- [ ] T062 [US2] Update load_balancer.tf to support multiple pool members (dynamic block for instances)

#### Multi-AZ and Database Replication

- [ ] T063 [US2] Update compute.tf with multi-AZ placement logic (distribute instances across zones)
- [ ] T064 [US2] Update database.tf with read replica configuration (point-in-time recovery enabled)
- [ ] T065 [US2] Add database_read_replica_count variable to variables.tf
- [ ] T066 [US2] Add validation to variables.tf ensuring compute subnet_ids span multiple zones
- [ ] T067 [US2] Update templates/user_data.sh.tpl with Redis connection configuration (TFE_REDIS_HOST environment variable)
- [ ] T068 [US2] Update templates/docker-compose.yaml.tpl with active-active environment variables

#### Load Balancer Session Persistence

- [ ] T069 [US2] Add session persistence configuration to load_balancer.tf (sticky sessions)
- [ ] T070 [US2] Update health check configuration in load_balancer.tf (support for multiple instances)

#### Outputs and Documentation

- [ ] T071 [US2] Add Redis outputs to outputs.tf (redis_endpoint, redis_port)
- [ ] T072 [US2] Add instance group outputs to outputs.tf (instance_group_id, instance_ids)
- [ ] T073 [US2] Update README.md with active-active deployment example

#### Testing for User Story 2

- [ ] T074 [US2] Create tests/active_active.tftest.hcl with multi-instance test structure
- [ ] T075 [US2] Add validate_redis_configuration run block to tests/active_active.tftest.hcl (command = plan)
- [ ] T076 [US2] Add deploy_ha_tfe run block to tests/active_active.tftest.hcl (command = apply, assert instance_count >= 2)
- [ ] T077 [US2] Add verify_load_distribution assertion to tests/active_active.tftest.hcl
- [ ] T078 [P] [US2] Create examples/active-active/ directory with main.tf, variables.tf, outputs.tf
- [ ] T079 [P] [US2] Create examples/active-active/terraform.tfvars.example with HA configuration
- [ ] T080 [P] [US2] Create examples/active-active/README.md with HA deployment instructions

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - basic deployment AND high availability deployment with autoscaling and distributed caching.

---

## Phase 5: User Story 3 - Manage Secrets and Certificates Securely (Priority: P3)

**Goal**: Ensure all sensitive data (TFE license, database passwords, TLS certificates, encryption keys) are stored in IBM Cloud Secrets Manager and injected at runtime with no secrets exposed in Terraform state or logs.

**Independent Test**: Verify all secret ARNs are passed as variables, check Terraform state contains only ARN references (not secret values), and confirm TFE application successfully retrieves and uses secrets from Secrets Manager during startup. Verify Activity Tracker logs secret access events.

### Implementation for User Story 3

#### Secrets Manager Integration

- [ ] T081 [P] [US3] Add data sources to data.tf for Secrets Manager secret retrieval (license, certificates, passwords)
- [ ] T082 [US3] Add TLS certificate secret variables to variables.tf (tls_cert_secret_crn, tls_key_secret_crn, tls_ca_bundle_secret_crn)
- [ ] T083 [US3] Update iam.tf with Secrets Manager access policies (VSI instance profile to Secrets Manager)
- [ ] T084 [US3] Add secrets_manager_instance_crn variable to variables.tf with CRN validation
- [ ] T085 [US3] Update locals.tf with secret path computations and secret ARN parsing logic

#### Certificate Management

- [ ] T086 [US3] Update load_balancer.tf to reference certificate secret from Secrets Manager (instead of direct certificate)
- [ ] T087 [US3] Add certificate expiration validation to variables.tf (optional warning)
- [ ] T088 [US3] Update templates/user_data.sh.tpl with Secrets Manager retrieval logic (IBM Cloud CLI or API calls)
- [ ] T089 [US3] Add custom CA bundle configuration to templates/user_data.sh.tpl (if provided)

#### Activity Tracker Integration

- [ ] T090 [P] [US3] Add Activity Tracker configuration to iam.tf (enable audit logging for secret access)
- [ ] T091 [US3] Add activity_tracker_crn variable to variables.tf (optional)
- [ ] T092 [US3] Update README.md with secrets management best practices section

#### State File Security

- [ ] T093 [US3] Add sensitive = true flags to all secret-related outputs in outputs.tf
- [ ] T094 [US3] Add validation to ensure no plaintext secrets in computed locals (locals.tf)
- [ ] T095 [US3] Update templates/docker-compose.yaml.tpl to use environment variables for secrets (not hardcoded)

#### Testing for User Story 3

- [ ] T096 [US3] Create tests/secrets_integration.tftest.hcl with secrets validation test structure
- [ ] T097 [US3] Add validate_secret_references run block to tests/secrets_integration.tftest.hcl (command = plan)
- [ ] T098 [US3] Add verify_no_plaintext_secrets run block to tests/secrets_integration.tftest.hcl (assert on state file)
- [ ] T099 [US3] Add verify_secrets_retrieval run block to tests/secrets_integration.tftest.hcl (command = apply)
- [ ] T100 [P] [US3] Update docs/tfe-bootstrap-secrets.md with certificate rotation procedure
- [ ] T101 [P] [US3] Create docs/tfe-cert-rotation.md with step-by-step certificate update guide

**Checkpoint**: All three user stories should now work independently - basic deployment, HA deployment, and secrets management with full security compliance.

---

## Phase 6: User Story 4 - Integrate with IBM Cloud Monitoring and Logging (Priority: P4)

**Goal**: Enable centralized observability by forwarding TFE application logs to IBM Log Analysis and metrics to IBM Cloud Monitoring for troubleshooting, alerting, and operational visibility.

**Independent Test**: Configure log forwarding destinations, generate TFE activity (workspace creation, plan execution), and verify logs appear in Log Analysis with proper metadata and metrics appear in Monitoring dashboards within 2 minutes.

### Implementation for User Story 4

#### Log Forwarding Configuration

- [ ] T102 [P] [US4] Create templates/fluent-bit-logdna.conf.tpl for IBM Log Analysis integration
- [ ] T103 [P] [US4] Create templates/fluent-bit-cos.conf.tpl for Object Storage log archival
- [ ] T104 [US4] Add log forwarding variables to variables.tf (enable_log_forwarding, log_forwarding_destination, logdna_ingestion_key_secret_crn)
- [ ] T105 [US4] Update templates/user_data.sh.tpl with Fluent Bit installation and configuration
- [ ] T106 [US4] Add Fluent Bit service configuration to templates/user_data.sh.tpl (systemd unit file)

#### Monitoring Integration

- [ ] T107 [US4] Add monitoring variables to variables.tf (enable_monitoring, sysdig_access_key_secret_crn, metrics_endpoint_port)
- [ ] T108 [US4] Update networking.tf with metrics endpoint security group rule (port 9090/9091)
- [ ] T109 [US4] Add metrics_endpoint_allowed_cidrs variable to variables.tf with CIDR validation
- [ ] T110 [US4] Update templates/docker-compose.yaml.tpl with TFE metrics endpoint configuration

#### Custom Fluent Bit Configuration

- [ ] T111 [US4] Add custom_fluent_bit_config variable to variables.tf (optional string)
- [ ] T112 [US4] Update templates/user_data.sh.tpl with custom Fluent Bit config injection logic
- [ ] T113 [US4] Add log parsing rules to templates/fluent-bit-logdna.conf.tpl (JSON format, metadata enrichment)

#### Outputs and Documentation

- [ ] T114 [US4] Add monitoring outputs to outputs.tf (metrics_endpoint_url, log_forwarding_status)
- [ ] T115 [US4] Update README.md with observability integration examples
- [ ] T116 [P] [US4] Create docs/observability.md with logging and monitoring setup guide
- [ ] T117 [P] [US4] Add alerting examples to docs/observability.md (CPU threshold, database connection failures)

#### Testing for User Story 4

- [ ] T118 [US4] Update tests/basic_deployment.tftest.hcl with log forwarding validation (optional)
- [ ] T119 [US4] Add log_forwarding_enabled assertion to tests/active_active.tftest.hcl

**Checkpoint**: Four user stories complete - basic, HA, secrets, and observability all working independently.

---

## Phase 7: User Story 5 - Customize Deployment for Air-Gapped Environments (Priority: P5)

**Goal**: Enable TFE deployment in air-gapped or restricted network environments using private endpoints, custom container registries, and HTTP proxies without any public internet connectivity.

**Independent Test**: Deploy with all public endpoints disabled, custom container registry configured, and HTTP proxy settings enabled, then verify TFE operates normally without any outbound internet connections. Confirm VCS integration works with on-premises VCS over private network.

### Implementation for User Story 5

#### Private Endpoint Configuration

- [ ] T120 [US5] Add private endpoint variables to variables.tf (use_private_endpoints, custom_endpoints map)
- [ ] T121 [US5] Update data.tf with private endpoint service URLs (ICD, COS, Secrets Manager private endpoints)
- [ ] T122 [US5] Update locals.tf with endpoint URL selection logic (public vs private)
- [ ] T123 [US5] Update storage.tf with private endpoint configuration for Object Storage
- [ ] T124 [US5] Update database.tf with private endpoint configuration for PostgreSQL
- [ ] T125 [US5] Update redis.tf with private endpoint configuration for Redis

#### Custom Container Registry

- [ ] T126 [US5] Add container registry variables to variables.tf (tfe_image_repository_url, registry_username_secret_crn, registry_password_secret_crn)
- [ ] T127 [US5] Update templates/docker-compose.yaml.tpl with custom registry authentication
- [ ] T128 [US5] Update templates/user_data.sh.tpl with container registry login logic
- [ ] T129 [US5] Add registry_ca_cert_secret_crn variable to variables.tf (for private registries with custom CA)

#### HTTP Proxy Configuration

- [ ] T130 [US5] Add HTTP proxy variables to variables.tf (http_proxy, https_proxy, no_proxy)
- [ ] T131 [US5] Update templates/user_data.sh.tpl with proxy environment variable configuration
- [ ] T132 [US5] Update templates/docker-compose.yaml.tpl with proxy settings for TFE container
- [ ] T133 [US5] Update locals.tf with no_proxy list generation (include IBM Cloud service endpoints)

#### VCS Integration for Air-Gapped

- [ ] T134 [US5] Add VCS private endpoint variables to variables.tf (vcs_url, vcs_oauth_token_secret_crn)
- [ ] T135 [US5] Update templates/user_data.sh.tpl with VCS connectivity validation
- [ ] T136 [US5] Add VCS CA bundle configuration to templates/user_data.sh.tpl (for on-premises VCS with custom certificates)

#### Network Validation

- [ ] T137 [US5] Add air-gapped mode validation to variables.tf (ensure private endpoints enabled if no_internet = true)
- [ ] T138 [US5] Update networking.tf with egress restrictions for air-gapped mode (no 0.0.0.0/0 routes)
- [ ] T139 [US5] Add internet connectivity validation to templates/user_data.sh.tpl (fail if unexpected internet access detected)

#### Outputs and Documentation

- [ ] T140 [US5] Add air-gapped configuration outputs to outputs.tf (endpoint_urls, registry_url)
- [ ] T141 [US5] Update README.md with air-gapped deployment example
- [ ] T142 [P] [US5] Create examples/air-gapped/ directory with main.tf, variables.tf, outputs.tf
- [ ] T143 [P] [US5] Create examples/air-gapped/terraform.tfvars.example with air-gapped configuration
- [ ] T144 [P] [US5] Create examples/air-gapped/README.md with air-gapped deployment instructions
- [ ] T145 [P] [US5] Create docs/air-gapped-deployment.md with prerequisites and network requirements

**Checkpoint**: All five user stories complete - basic, HA, secrets, observability, and air-gapped deployments all functional.

---

## Phase 8: Production Hardening (Cross-Cutting Enhancements)

**Purpose**: Security enhancements, comprehensive validation, DNS integration, and complete documentation for production readiness.

### Enhanced Validation

- [ ] T146 [P] Create validation rules for all 31 input variables in variables.tf
- [ ] T147 [P] Add cross-variable dependency validation to variables.tf (operational mode vs instance count)
- [ ] T148 [P] Add subnet zone validation to variables.tf (ensure multi-AZ distribution)
- [ ] T149 [P] Add comprehensive error messages for all validation rules in variables.tf

### DNS Integration

- [ ] T150 Create dns.tf with IBM Cloud DNS Services integration (optional)
- [ ] T151 Add DNS variables to variables.tf (create_dns_record, dns_zone_id, dns_record_name)
- [ ] T152 Add DNS record resource to dns.tf (pointing to load balancer)
- [ ] T153 Add DNS outputs to outputs.tf (dns_record_fqdn, dns_zone_name)

### Tagging and Resource Management

- [ ] T154 Update locals.tf with comprehensive tagging strategy (cost allocation, environment, owner)
- [ ] T155 Add common_tags variable to variables.tf (map of string)
- [ ] T156 Apply tags to all resources in compute.tf, database.tf, storage.tf, load_balancer.tf
- [ ] T157 Add resource naming validation to locals.tf (ensure IBM Cloud naming constraints)

### Documentation Suite

- [ ] T158 [P] Create docs/deployment-customizations.md with advanced configuration examples
- [ ] T159 [P] Create docs/tfe-version-upgrades.md with TFE version upgrade procedure
- [ ] T160 [P] Create docs/troubleshooting.md with common issues and solutions
- [ ] T161 [P] Create docs/backup-and-recovery.md with backup strategy and restore procedures
- [ ] T162 [P] Update README.md with complete variable reference (use terraform-docs)
- [ ] T163 [P] Add architecture diagrams to README.md (network topology, service dependencies)
- [ ] T164 [P] Add prerequisites checklist to README.md (IBM Cloud quotas, service availability)

### Security Review

- [ ] T165 Review all security group rules in networking.tf (ensure least privilege)
- [ ] T166 Review all IAM policies in iam.tf (ensure minimal required permissions)
- [ ] T167 Validate TLS 1.2+ enforcement in load_balancer.tf
- [ ] T168 Add encryption verification to storage.tf and database.tf (ensure Key Protect integration)
- [ ] T169 Add sensitive flags to all outputs containing credentials in outputs.tf

---

## Phase 9: Testing & CI/CD (Automated Validation)

**Purpose**: Comprehensive testing with native Terraform test framework and GitHub Actions workflows for automated validation.

### Test Suite Development

- [ ] T170 [P] Create tests/plan_validation.tftest.hcl for fast validation with command = plan
- [ ] T171 [P] Add variable validation tests to tests/plan_validation.tftest.hcl (invalid CRNs, invalid CIDR blocks)
- [ ] T172 [P] Add cross-variable validation tests to tests/plan_validation.tftest.hcl
- [ ] T173 Update tests/basic_deployment.tftest.hcl with comprehensive assertions (all outputs present)
- [ ] T174 Update tests/active_active.tftest.hcl with autoscaling validation
- [ ] T175 Update tests/secrets_integration.tftest.hcl with Activity Tracker log verification
- [ ] T176 [P] Create tests/fixtures/cleanup/ helper module for test resource cleanup
- [ ] T177 Add test documentation to tests/README.md (how to run tests, cost estimates)

### GitHub Actions Workflows

- [ ] T178 [P] Create .github/workflows/terraform-validate.yml for fmt, validate, lint on every PR
- [ ] T179 [P] Create .github/workflows/terraform-plan-tests.yml for fast plan-only tests (command = plan)
- [ ] T180 Create .github/workflows/terraform-integration-tests.yml with manual approval gate for apply tests
- [ ] T181 Add test matrix to .github/workflows/terraform-integration-tests.yml (us-south, us-east, eu-de regions)
- [ ] T182 Add cleanup job to .github/workflows/terraform-integration-tests.yml (runs on failure)
- [ ] T183 [P] Create .github/workflows/release.yml for version tagging and changelog generation

### Multi-Region Testing

- [ ] T184 Update tests/basic_deployment.tftest.hcl with region parameter
- [ ] T185 Update tests/active_active.tftest.hcl with region parameter
- [ ] T186 Validate tests pass in us-south region
- [ ] T187 Validate tests pass in us-east region
- [ ] T188 Validate tests pass in eu-de region

### Module Publication

- [ ] T189 Create CHANGELOG.md following Keep a Changelog format
- [ ] T190 Create CONTRIBUTING.md with contribution guidelines
- [ ] T191 Add LICENSE file (MPL 2.0 recommended for Terraform modules)
- [ ] T192 Create .github/PULL_REQUEST_TEMPLATE.md
- [ ] T193 Create .github/ISSUE_TEMPLATE/ with bug and feature request templates
- [ ] T194 Tag initial release version (v1.0.0)
- [ ] T195 Publish module to Terraform Registry (if public)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1: Setup**: No dependencies - can start immediately
- **Phase 2: Foundational**: Depends on Setup completion (T001-T009) - **BLOCKS all user stories**
- **Phase 3: User Story 1 (P1)**: Depends on Foundational completion (T010-T020) - MVP delivery
- **Phase 4: User Story 2 (P2)**: Depends on Foundational completion (T010-T020) - Can proceed in parallel with US1
- **Phase 5: User Story 3 (P3)**: Depends on Foundational completion (T010-T020) - Can proceed in parallel with US1/US2
- **Phase 6: User Story 4 (P4)**: Depends on Foundational completion (T010-T020) - Can proceed in parallel with other stories
- **Phase 7: User Story 5 (P5)**: Depends on Foundational completion (T010-T020) - Can proceed in parallel with other stories
- **Phase 8: Production Hardening**: Depends on desired user stories being complete (typically US1-US3 minimum)
- **Phase 9: Testing & CI/CD**: Can proceed in parallel with implementation phases, tests written per story

### User Story Dependencies

```
Setup (Phase 1) → Foundational (Phase 2) → [All User Stories can proceed in parallel]
                                          ├─ User Story 1 (P1) ← Independent
                                          ├─ User Story 2 (P2) ← Independent (builds on US1 patterns)
                                          ├─ User Story 3 (P3) ← Independent (enhances US1/US2 security)
                                          ├─ User Story 4 (P4) ← Independent (adds observability to any deployment)
                                          └─ User Story 5 (P5) ← Independent (alternative deployment mode)
```

### Within Each User Story

**User Story 1 Task Flow**:
```
T021-T024 [P] → T025-T029 → T030-T032 → T033-T043 → T044-T053 [P]
(Resources)   (Variables)  (Validation) (Integration)  (Tests/Docs)
```

**User Story 2 Task Flow**:
```
T054-T057 [P] → T058-T062 → T063-T070 → T071-T073 → T074-T080 [P]
(Redis/Config) (Autoscaling) (Multi-AZ)  (Outputs)   (Tests/Docs)
```

**User Story 3 Task Flow**:
```
T081-T085 [P] → T086-T089 → T090-T095 → T096-T101 [P]
(Secrets/IAM)  (Certificates) (Security)  (Tests/Docs)
```

**User Story 4 Task Flow**:
```
T102-T106 [P] → T107-T113 → T114-T119 [P]
(Log Forwarding) (Monitoring) (Outputs/Tests)
```

**User Story 5 Task Flow**:
```
T120-T125 [P] → T126-T133 → T134-T139 → T140-T145 [P]
(Private Endpoints) (Registry/Proxy) (VCS/Validation) (Outputs/Docs)
```

### Parallel Opportunities

Within each phase, all tasks marked **[P]** can be executed in parallel by different team members:

**Phase 1 (Setup)**: T002, T003, T004, T005, T006, T007, T008, T009 can all run simultaneously

**Phase 2 (Foundational)**: T019, T020 can run in parallel with T010-T018 sequence

**User Story 1**: 
- T021, T022, T023, T024 (core resources) can all run in parallel
- T044-T053 (tests and docs) can all run in parallel

**User Story 2**:
- T054, T055 can run in parallel initially
- T074-T080 (tests and docs) can all run in parallel

**All User Stories (Phase 3-7)**: Once foundational phase is complete, all user stories can be implemented in parallel if team capacity allows.

---

## Parallel Example: User Story 1 Implementation

With 3 developers after foundational phase is complete:

```bash
# Developer A: Core Resources (parallel)
Task T021: "Create compute.tf with VSI instance resource"
Task T022: "Create database.tf with PostgreSQL resource"
Task T023: "Create storage.tf with Object Storage bucket"
Task T024: "Create load_balancer.tf with NLB resource"

# Developer B: Variables and Validation (sequential)
Task T025-T032: "Add and validate all US1 variables"

# Developer C: Templates and Integration (sequential)
Task T033-T043: "Complete templates and integration"

# All Developers: Tests and Documentation (parallel)
Task T044-T053: "Tests, examples, and documentation"
```

---

## Implementation Strategy

### MVP First (Recommended - User Story 1 Only)

1. ✅ Complete Phase 1: Setup (T001-T009)
2. ✅ Complete Phase 2: Foundational (T010-T020) - **CRITICAL BLOCKER**
3. ✅ Complete Phase 3: User Story 1 (T021-T053)
4. **STOP and VALIDATE**: 
   - Run `terraform plan` and `terraform apply` with basic configuration
   - Verify TFE URL is accessible via HTTPS
   - Create initial admin user
   - Create test workspace and run Terraform plan
5. Deploy/demo if validation passes

**Estimated Timeline**: 2-3 weeks for fully functional MVP

### Incremental Delivery (Recommended)

Each phase adds value independently:

1. **Setup + Foundational** → Foundation ready (1 week)
2. **+ User Story 1** → MVP TFE deployment working (2-3 weeks total) ✅ **First Demo**
3. **+ User Story 2** → High availability deployment ready (4 weeks total) ✅ **Second Demo**
4. **+ User Story 3** → Enterprise-grade security compliance (5 weeks total) ✅ **Third Demo**
5. **+ User Story 4** → Full observability integration (6 weeks total) ✅ **Fourth Demo**
6. **+ User Story 5** → Air-gapped deployment capability (7 weeks total) ✅ **Fifth Demo**
7. **+ Production Hardening** → Production-ready module (8-9 weeks total)
8. **+ Testing & CI/CD** → Published with automated validation (10-11 weeks total)

### Parallel Team Strategy

With 3-4 developers working simultaneously:

1. **Week 1**: Entire team completes Setup + Foundational together (T001-T020)
2. **Week 2-3**: Once Foundational is done, split team:
   - Developer A: User Story 1 (T021-T053) - MVP path
   - Developer B: User Story 2 (T054-T080) - HA features
   - Developer C: User Story 3 (T081-T101) - Security features
   - Developer D: User Story 4 (T102-T119) - Observability
3. **Week 4-5**: Integration and hardening
   - Developer A+B: User Story 5 (T120-T145)
   - Developer C+D: Production Hardening (T146-T169)
4. **Week 6-7**: Testing and CI/CD (T170-T195)

**Estimated Timeline**: 6-7 weeks with parallel execution

---

## Task Summary

**Total Tasks**: 195

**By Phase**:
- Phase 1 (Setup): 9 tasks
- Phase 2 (Foundational): 11 tasks (**BLOCKING** - must complete first)
- Phase 3 (User Story 1 - MVP): 33 tasks
- Phase 4 (User Story 2 - HA): 27 tasks
- Phase 5 (User Story 3 - Secrets): 21 tasks
- Phase 6 (User Story 4 - Observability): 18 tasks
- Phase 7 (User Story 5 - Air-Gapped): 26 tasks
- Phase 8 (Production Hardening): 24 tasks
- Phase 9 (Testing & CI/CD): 26 tasks

**By Priority (User Stories)**:
- P1 (US1 - MVP): 33 tasks → **Immediate value**
- P2 (US2 - HA): 27 tasks → **Production readiness**
- P3 (US3 - Secrets): 21 tasks → **Security compliance**
- P4 (US4 - Observability): 18 tasks → **Operational visibility**
- P5 (US5 - Air-Gapped): 26 tasks → **Special environments**

**Parallelizable Tasks**: 68 tasks marked [P] can run simultaneously

**MVP Scope** (Setup + Foundational + US1): 53 tasks (27% of total) → Delivers working TFE deployment

**Production-Ready Scope** (MVP + US2 + US3 + Hardening): 140 tasks (72% of total)

**Full Feature Scope** (All phases): 195 tasks

---

## Suggested Delivery Milestones

### Milestone 1: MVP (Week 3)
- **Deliverable**: Single-instance TFE deployment on IBM Cloud
- **Tasks**: T001-T053 (Setup + Foundational + User Story 1)
- **Demo**: Access TFE via HTTPS, create admin user, run test workspace

### Milestone 2: Production HA (Week 5)
- **Deliverable**: High availability TFE with autoscaling and Redis
- **Tasks**: T054-T080 (User Story 2)
- **Demo**: Multi-instance deployment, instance termination resilience

### Milestone 3: Security Compliance (Week 7)
- **Deliverable**: Secrets Manager integration, zero plaintext secrets
- **Tasks**: T081-T101 (User Story 3)
- **Demo**: Certificate rotation, Activity Tracker audit logs

### Milestone 4: Full Observability (Week 9)
- **Deliverable**: Centralized logging and monitoring
- **Tasks**: T102-T119 (User Story 4)
- **Demo**: Log Analysis integration, Monitoring dashboards

### Milestone 5: Enterprise Hardening (Week 11)
- **Deliverable**: Production-ready with comprehensive documentation
- **Tasks**: T146-T169 (Production Hardening)
- **Demo**: Complete documentation review, security audit

### Milestone 6: Release (Week 11)
- **Deliverable**: Published module with automated testing
- **Tasks**: T170-T195 (Testing & CI/CD)
- **Demo**: GitHub Actions pipeline, multi-region tests passing

---

## Notes

- **[P]** tasks target different files and can run in parallel without conflicts
- **[Story]** labels (US1-US5) map tasks to user stories for traceability
- Each user story is independently implementable and testable after Foundational phase
- Tests use native Terraform test framework (.tftest.hcl files, not Go-based frameworks)
- Cost control: Integration tests with `command = apply` behind manual approval gate
- Fast validation: Use `command = plan` tests for rapid feedback
- Stop at any checkpoint to validate story independence
- All file paths are exact and follow the 14-file Terraform module structure
- Commit after each task or logical group for incremental progress tracking
