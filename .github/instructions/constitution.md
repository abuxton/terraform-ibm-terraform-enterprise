# Terraform AI-Assisted Development Constitution

**Organization**: Hashicorp
**Version**: 1.0.0
**Effective Date**: December 2025
**Purpose**: Governing principles for AI-assisted Terraform code generation for application teams consuming infrastructure services

---

## I. Foundational Principles

### 1.1 Module-First Architecture

**Principle**: All infrastructure MUST be provisioned through approved modules from the Private Module Registry.

**Rationale**: Direct resource declarations bypass organizational standards, security controls, and governance policies. The platform team has invested significant effort in creating secure, compliant, and tested modules.

**Implementation**:

- You MUST search and prioritize existing modules from `https://registry.terraform.io`
-
- **Module Source Requirement**: The `source` attribute for all modules SHOULD e pubic to guarantee reusability
  - Example:

    ```hcl
    module "example" {
      source  = "modulename/"
      version = "~> 1.0.0"
      # other inputs...
    }
    ```

  - You SHOULD use public registry sources or shortcuts (e.g., `hashicorp/` or `terraform-aws-modules/`) for module consumption.
  - This ensures modules are vetted, compliant, and maintained by the platform team.
- If a required module doesn't exist, you MUST surface this gap to the user and platform team rather than improvising with raw resources
- Module consumption MUST follow semantic versioning constraints (e.g., `version = "~> 2.1.0"`)

### 1.2 Specification-Driven Development

**Principle**: Infrastructure code generation MUST be driven by explicit specifications, not implicit assumptions. Specifications are the source of truth for all infrastructure implementations.

**Rationale**: "Vibe-coding" leads to inconsistent implementations, security gaps, and maintenance nightmares. Specifications create auditable decision trails and enable traceability between requirements and code. Spec-driven development ensures all infrastructure changes are intentional, documented, and reversible.

**Specification Requirements**:

- ALL infrastructure changes MUST be preceded by a written specification document
- Specifications MUST include:
  - **Purpose**: Clear business objective and use case
  - **Scope**: What resources/systems are affected
  - **Compliance Requirements**: Security, regulatory, and organizational standards
  - **Performance Needs**: Scalability, availability, and performance requirements
  - **Cost Constraints**: Budget limitations and cost optimization expectations
  - **Success Criteria**: Measurable outcomes for validation
  - **Acceptance Tests**: How to verify the infrastructure meets requirements
- Specifications MUST be stored in version control (e.g., `/specs` directory) alongside code
- Each specification MUST have a unique identifier (e.g., `SPEC-001`, `APP-INFRA-2025-01`)

**Implementation**:

- You MUST request clarification on ambiguous requirements before generating code
- You MUST refuse to generate code without a documented specification
- Generated code MUST include inline comments referencing the specification identifier and specific requirements it implements
- Example: `# Per SPEC-001: Enable encryption at rest for compliance with SOC2`
- All specification changes MUST flow through the same branch approval process as code changes
- You MUST validate specifications against organizational constraints before code generation
- You MUST create acceptance tests based on specification success criteria

### 1.3 Security-First Automation

**Principle**: Generated code MUST assume zero trust and implement security controls by default.

**Rationale**: AI-generated infrastructure code requires secure patterns for handling sensitive data, as AI can inadvertently introduce misconfigurations or overlook security best practices.

**Implementation**:

- You MUST never generate static, long-lived credentials in code or configuration
- All provider authentication MUST use short-lived dynamic credentials (workspace variable sets are pre-configured for this)
- You MUST use ephemeral resources for handling sensitive values instead of data sources or static secrets (see <https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral>)
- You MUST include security context in code comments (e.g., "Using ephemeral resource to securely handle database password per ORG-SEC-001")

---

## II. HCP Terraform Prerequisites

### 2.1 Required Configuration Details

**Standard**: HCP Terraform configuration details MUST be determined from the current remote git repository or provided by user before any Terraform operations.

**Prerequisites**:

- HCP Terraform Organization Name
- HCP Terraform Project Name
- HCP Terraform Workspace Name for Dev environment

**Rules**:

- You MUST use Terraform MCP server tools to determine organization, project and dev workspace name based on the current remote git repository
- If multiple options exist or details cannot be determined automatically, you MUST prompt user to select/provide these configuration details
- You MUST always validate that these configuration details are available before invoking any tools provided by Terraform MCP server
- The Terraform MCP server MUST use the organization, project and workspace values for calling any tools
- Organization and project context MUST be validated before module registry access

**Implementation**:

- Configuration details MUST be automatically detected from the current git repository using Terraform MCP server tools
- When automatic detection is not possible or returns multiple options, you MUST present choices to the user for selection
- Missing prerequisites MUST be surfaced to the user with clear instructions and options
- All HCP Terraform API calls for ephemeral workspace or workspace variables related operations MUST use the specified organization, project and workspace context
- User-provided configuration details MUST be validated against available HCP Terraform resources before proceeding

---

## III. Code Generation Standards

### 3.1 Repository Structure

**Standard**: One application, one repository, git branch per environment.

**Structure**:

```bash
/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── locals.tf
├── README.md
└── .gitignore
```

**Git Branch Strategy (Gitflow)**:

This project uses Gitflow branching model with the following branch structure:

**Long-Lived Branches**:
- `main` → Production environment (stable, release-ready code)
- `staging` → Staging environment (pre-production validation)
- `dev` → Development environment (integration branch for feature work)

**Short-Lived Branches** (branched from `dev`, merged back via pull request):
- `feature/*` → Feature development (naming: `feature/short-description`, e.g., `feature/add-vpc-flow-logs`)
- `bugfix/*` → Bug fixes (naming: `bugfix/issue-number-description`, e.g., `bugfix/123-security-group-rules`)
- `hotfix/*` → Emergency production fixes (branched from `main`, naming: `hotfix/issue-description`)
- `refactor/*` → Code refactoring work (naming: `refactor/description`, e.g., `refactor/consolidate-locals`)
- `chore/*` → Maintenance tasks (naming: `chore/description`, e.g., `chore/update-terraform-version`)

**Branch Naming Conventions**:
- Prefix with branch type: `feature/`, `bugfix/`, `hotfix/`, `refactor/`, `chore/`
- Use lowercase with hyphens for spacing
- Keep names descriptive but concise (max 50 characters total)
- Include ticket/issue number when applicable (e.g., `feature/123-vpc-configuration`)
- Invalid: `Feature/VPC`, `my_feature`, `feature_vpc_setup`
- Valid: `feature/vpc-setup`, `bugfix/123-sg-rules`, `hotfix/security-patch`

**Branch Protection Rules**:

- Direct commits to `main`, `staging`, and `dev` branches are STRICTLY PROHIBITED
- All changes MUST originate from properly-named short-lived branches
- When creating a feature/bugfix branch, ensure you are on the `dev` branch. If not, switch first: `git checkout dev`
- Branch creation: `git checkout -b feature/description`
- Pull requests with mandatory human review REQUIRED for all merges
- Pull requests MUST reference the specification identifier (e.g., "Implements SPEC-001")
- Each PR MUST include a link to the related specification document

**Rules**:

- Each git branch maps to ONE HCP Terraform workspace (pre-configured during application onboarding)
- Environment-specific values MUST be managed through workspace variables, NOT hardcoded in code
- Shared configuration MAY be extracted to local modules if needed for composition

## Initialize TFLint and pre-commit

> always available in devcontainer

```bash

echo "Initializing TFLint..."
if ! tflint --init; then
    echo "WARNING: TFLint initialization failed, but continuing..."
fi

# Enable pre-commit hooks if available (optional step)
if command -v pre-commit &> /dev/null; then
    echo "Installing pre-commit hooks..."
    pre-commit install
else
    echo "Pre-commit not available - skipping (this is optional)"
fi
```

## Verify directory structure

echo "Module directory structure:"
ls -la

### 3.2 File Organization

**Standard**: Terraform files MUST follow organizational conventions.

**Rules**:

- `main.tf`: Module instantiations and core infrastructure logic
- `variables.tf`: Input variable declarations with descriptions, types, and validation
- `outputs.tf`: Output declarations with descriptions for downstream consumption, outputs should pass back common expected values, examples, names and addresses.
- `providers.tf`: provider configuration blocks
- `versions.tf` : terraform block required_version, required_providers
- `locals.tf` : Terraform locals
-

**Prohibitions**:

- You MUST NOT create monolithic single-file configurations exceeding 300 lines
- You MUST NOT intermingle resource types without logical grouping
- You MUST NOT use default values for security-sensitive variables

### 3.3 Naming Conventions

**Standard**: Names MUST be predictable, consistent, and follow HashiCorp naming standards.

**Format**:

- Resources: `<app>-<resource-type>-<purpose>` (e.g., `api-ec2-web`, `database-rds-primary`)
- Variables: `snake_case` with descriptive names
- Modules: `<provider>-<resource>-<purpose>` (e.g., `aws-vpc-standard`)

**Rules**:

- You MUST follow HashiCorp naming standards (<https://developer.hashicorp.com/terraform/plugin/best-practices/naming>)
- You MUST infer naming from specification or request clarification
- Names MUST NOT include sensitive information (account IDs, secrets, PII)
- Names MUST be idempotent and not include timestamps or random values unless functionally required

### 3.4 Variable Management

**Standard**: Variables MUST be explicitly declared with comprehensive metadata.

**Template**:

```hcl
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

**Rules**:

- ALL variables MUST include `description` explaining purpose and valid values
- Variables MUST include `type` constraints (never use implicit `any`)
- Security-sensitive variables MUST be marked as `sensitive = true`
- Variables SHOULD include `validation` blocks for business logic constraints
- You leverage workspace variable sets (Vault URL, org standards) and NOT redefine them

### 3.5 Module Usage Patterns

**Standard**: Module consumption MUST follow organizational patterns.

**Example**:

```hcl
module "vpc" {
  source  = "app.terraform.io/<org-name>/vpc/aws"
  version = "~> 3.2.0"

  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  enable_flow_logs    = true  # Required by ORG-SEC-002

  tags = local.common_tags
}
```

**Rules**:

- You MUST use version constraints (`~>`) to allow patch updates while preventing breaking changes
- Module inputs MUST map to declared variables, NOT hardcoded values
- You MUST include comments explaining non-obvious module configurations
- Module source MUST explicitly reference the private registry e.g. `<app.terraform.io/<org-name>`, never generic registry shortcuts

---

## IV. Security and Compliance

### 3.1 Credential Management

**Policy**: No static credentials SHALL be generated or stored in code.

**Implementation**:

- Workspace variable sets are pre-configured for dynamic provider credentials - you MUST NOT override these
- Provider authentication MUST leverage short-lived dynamic credentials:

  ```hcl
  provider "aws" {
    # Short-lived dynamic credentials provided automatically
    # via pre-configured workspace variable sets
  }
  ```

- You MUST NOT generate `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` or similar static credential variables
- You MUST reference dynamic credential workflow in documentation

### 3.2 Security Best Practices

**Policy**: Generated code must embed security best practices and follow organizational standards.

**Implementation**:

- Generated infrastructure MUST align with security requirements (e.g., encryption enabled, public access restricted)
- You SHOULD include security rationale comments:

  ```hcl
  # Encryption enabled to meet organizational security standards
  encryption_enabled = true
  ```

- Security patterns MUST be implemented proactively, not reactively
- Non-compliant patterns MUST be avoided even if technically functional

### 3.3 Secrets Management

**Policy**: Secrets MUST never appear in Terraform code or state.

**Rules**:

- You MUST use ephemeral resources for handling sensitive values instead of data sources or static secrets
- Database passwords, API keys, certificates MUST be handled using ephemeral resources:

  ```hcl
  ephemeral "vault_secret" "db_password" {
    path = "secret/data/${var.environment}/database"
  }
  ```

- You MUST mark outputs containing secrets with `sensitive = true`
- Prefer ephemeral resources over data sources for secret retrieval to minimize exposure in state

### 3.4 Least Privilege by Default

**Policy**: Generated infrastructure MUST implement principle of least privilege.

**General Rules**:

- Identity and access management policies MUST be scoped to minimum required permissions
- Network security rules MUST restrict ingress to known sources and specific ports
- Public access MUST be explicitly justified, documented, and reviewed
- You MUST prefer module-defined roles and policies over custom inline configurations
- All data at rest MUST be encrypted using cloud provider managed keys or customer-managed keys
- All data in transit MUST use TLS/SSL encryption with minimum version 1.2
- Logging and monitoring MUST be enabled for all security-sensitive resources
- Resource tagging MUST include security classification and data sensitivity levels
- Default credentials and service accounts MUST NOT be used for application workloads
- Cross-region replication and backup strategies MUST align with data residency requirements

**AWS-Specific Rules**:

- Security Groups MUST deny all traffic by default, only allowing specific required ports and sources
- S3 buckets MUST block public access unless explicitly required for public hosting
- IAM roles MUST use specific resource ARNs instead of wildcards (`*`) when possible
- RDS instances MUST NOT be publicly accessible unless explicitly justified
- EC2 instances MUST use IAM instance profiles instead of embedded credentials
- Lambda functions MUST use least privilege execution roles with specific service permissions

**GCP-Specific Rules**:

- Firewall rules MUST use specific source ranges instead of `0.0.0.0/0` unless justified
- Cloud Storage buckets MUST use uniform bucket-level access with specific IAM bindings
- Service accounts MUST be granted minimal roles, prefer predefined roles over primitive roles
- Compute instances MUST NOT use default service accounts for application workloads
- Cloud SQL instances MUST require SSL and use private IP when possible
- Cloud Functions MUST use least privilege service account with specific API access

**Azure-Specific Rules**:

- Network Security Groups MUST deny all traffic by default with explicit allow rules
- Storage accounts MUST disable public blob access unless required for static websites
- Key Vault access policies MUST grant minimal permissions per service principal
- Virtual machines MUST use managed identities instead of service principal credentials
- SQL databases MUST use private endpoints and disable public network access when possible
- Function apps MUST use managed identity with specific resource access permissions

---

## V. Workspace and Environment Management

### 4.1 HCP Terraform Workspace Management

**Standard**: HCP Terraform workspaces are pre-provisioned and managed according to organizational policies.

**Workspace Creation Rules**:

- You MUST NEVER create or suggest creating new HCP Terraform workspaces for application teams
- All application workspaces (sandbox, dev, staging, prod) are pre-created during the application team onboarding process
- Workspace provisioning is managed exclusively by the platform team through established onboarding workflows
- This code agent will used workspaces starting with sandbox-<name>

**Ephemeral Workspace Rules**:

- You MUST create ephemeral HCP Terraform workspaces ONLY for testing AI-generated Terraform configuration code
- Ephemeral workspaces MUST be connected to the current `feature/*` branch of the remote Git repository and will use Terraform CLI
- Before running terraform init you must configure credentials, TFE_TOKEN is already set as an environment. variable. See example.

```bash
  mkdir -p ~/.terraform.d && cat > ~/.terraform.d/credentials.tfrc.json << EOF
    {
      "credentials": {
        "app.terraform.io": {
          "token": $TFE_TOKEN
        }
      }
    }
    EOF
```

- Run terraform validate to confirm code is syntactically correct
- The current feature branch MUST be committed and pushed to the remote Git repository BEFORE creating the ephemeral workspace
- ensure the terraform variables are validated by the user before proceeding, including regions values and other required inputs.
- You MUST create all necessary workspace variables at the ephemeral workspace level based on required variables defined in `variables.tf` in the `feature/*` branch
- Ephemeral workspaces MUST be used to validate terraform plan and apply operations before promoting changes
- Upon successful testing in the ephemeral workspace, you MUST create corresponding workspace variables for the dev workspace
- You MUST use the following tools to test AI-generated Terraform code:
  - `create_workspace` to create ephemeral workspace
  - `create_workspace_variable` to create workspace level variables
  - `create_run` to create a new Terraform run in the specified ephemeral workspace
- Ephemeral workspaces MUST be deleted after successful testing to avoid unnecessary costs

**Variable Promotion Workflow**:

1. Test variables in ephemeral workspace connected to `feature/*` branch
2. Confirm variable value with user in prompt before proceeding
3. Validate successful terraform run operations (plan and apply)
4. Create identical workspace variables in the dev workspace
5. Document variable requirements and values for staging and production promotion

### 4.2 Variable Sets

**Standard**: Leverage organization-wide variable sets for common configuration.

**Common Variable Sets**:

- `vault-authentication`: Vault URL, namespace, role for dynamic credentials
- `tags-standard`: Organization, cost-center, compliance tags
- `network-config`: Shared network CIDRs, DNS zones
- `monitoring-config`: Logging endpoints, metrics exporters

**Rules**:

- You MUST NOT duplicate variable set values in code
- You SHOULD document expected variable sets in `README.md`
- Application-specific variables MUST be defined at workspace level, not in code

### 4.3 Environment Promotion (Gitflow Workflow)

**Standard**: Changes flow through gitflow branches with specification verification and mandatory human review at each stage.

**Specification-Driven Promotion Workflow**:

1. **Specification Phase**:
   - Create specification document in `/specs` directory (e.g., `SPEC-001-vpc-enhancement.md`)
   - Include all requirements, compliance needs, success criteria
   - Commit and push specification to `dev` branch
   - Obtain stakeholder approval on specification

2. **Feature Development Phase**:
   - Create feature branch from `dev`: `git checkout -b feature/spec-001-description`
   - Branch name MUST reference the specification ID
   - Generate code per specification requirements
   - Add inline comments linking code to specification sections
   - Commit code with message: `feat: Implement SPEC-001 - Description [feature/spec-001-name]`

3. **Development Integration** (PR: feature → dev):
   - Create pull request from feature branch to `dev`
   - PR title MUST include specification ID: `feat: Implement SPEC-001 - Description`
   - PR description MUST link to specification: "Implements specification `SPEC-001-vpc-enhancement.md`"
   - Human review validates code matches specification
   - Reviewer verifies specification acceptance criteria are met
   - Upon approval: Merge and delete feature branch

4. **Staging Promotion** (PR: dev → staging):
   - After dev environment validation
   - Create pull request from `dev` to `staging`
   - Title: `release: Promote SPEC-001 implementation to staging`
   - Reference all associated specifications in PR description
   - Infrastructure team reviews for staging validation
   - Upon approval: Merge (do NOT delete `dev`)
   - Staging workspace automatically deploys via VCS workflow

5. **Production Promotion** (PR: staging → main):
   - After staging environment validation and sign-off
   - Create pull request from `staging` to `main`
   - Title: `release: Promote to production - SPEC-001`
   - Require explicit approval from platform/infrastructure leads
   - Include change summary and rollback procedure
   - Upon approval: Merge (do NOT delete `staging`)
   - Production workspace automatically deploys via VCS workflow

**Hotfix Workflow** (Emergency Production Fixes):

- Branch from `main`: `git checkout -b hotfix/issue-description`
- Apply critical fix with specification reference
- Create PRs to both `main` and `staging` for consistency
- After merge to `main`: backport changes to `staging` and `dev`
- Document hotfix specification for future review

**Branch Protection Requirements**:

- Direct commits to `main`, `staging`, and `dev` branches are STRICTLY PROHIBITED
- All changes MUST originate from properly-named feature/bugfix/hotfix/refactor/chore branches
- Human-in-the-loop review REQUIRED for ALL pull requests
- Pull request reviews MUST verify:
  - Specification ID is referenced
  - Code implements specification requirements
  - Acceptance criteria are met
  - Branch naming follows gitflow conventions
- Feature branches MUST be deleted after successful merge
- Long-lived branches (`dev`, `staging`, `main`) are NEVER deleted

**Promotion Rules**:

- You MUST generate identical code structure across all branches
- Environment-specific values MUST be externalized to workspace variables
- Each promotion MUST include specification verification checklist
- Production deployments REQUIRE:
  - Specification approval
  - Staging validation sign-off
  - Platform team explicit approval
  - Rollback plan documented
- Workspace-level security policies enforce stricter rules for production
- All specification changes undergo same promotion workflow as code changes

---

## VI. Code Quality and Maintainability

### 5.1 Documentation Requirements

**Standard**: AI-generated code MUST be self-documenting and include external documentation with automated generation.

**Requirements**:

- Every repository MUST include comprehensive `README.md` with:
  - Purpose and scope
  - Prerequisites (workspace setup, variable sets)
  - Module dependencies
  - Deployment instructions (including `terraform init` and `terraform plan` as these are automatically handled by HCP Terraform VCS workflow)
  - Troubleshooting guide
- README.md MUST be automatically generated and updated using `terraform-docs` via Git pre-commit hooks
- Complex logic MUST include inline comments explaining rationale
- Module selections MUST be justified in comments
- All variables and outputs MUST have proper descriptions for `terraform-docs` automatic documentation generation

### 5.2 Code Style

**Standard**: Generated code MUST follow HashiCorp Style Guide.

**Rules**:

- Use `terraform fmt` for formatting
- User `terraform init` then `terraform validate` for syntax validation
- Alphabetize arguments within blocks for consistency
- Use consistent argument ordering: required args first, optional args second, meta-args last
- You MUST run `terraform fmt` on generated code before presenting to users

### 5.3 Testing and Validation

**Standard**: Generated code MUST be validated before commit using automated Git pre-commit hooks.

**Git Pre-commit Hook Configuration**:

- Git pre-commit hook MUST be configured to update README using `terraform-docs` for automatic documentation generation
- Git pre-commit hook MUST be configured to format code using `terraform fmt` for consistent code formatting
- Git pre-commit hook MUST be configured to validate syntax using `terraform validate` for configuration validation
- Git pre-commit hook MUST be configured with `tflint` to perform linting and identify configuration errors
- Git pre-commit hook MUST be configured with `tfsec` to perform static code analysis for security vulnerabilities
- pre-commit should not be bypassed unless the user has authorized

**Validation Steps**:

- You SHOULD recommend configuring pre-commit hooks in the development environment
- run `terraform init` or `terraform plan` using a cloud block to specify the workspace in your specified HCP terraform project
- Reviewing the terraform plan output in the HCP Terraform UI for the dev workspace before promoting to other environments
- Review and resolve any detailed workspace output or warnings from the workspace.

### 5.4 Version Control

**Standard**: Generated code MUST be version controlled with meaningful commits.

**Rules**:

- `.gitignore` MUST exclude:

  ```bash
  .terraform/
  *.tfstate
  *.tfstate.backup
  .terraform.lock.hcl
  *.tfvars  # May contain sensitive data
  ```

- You SHOULD suggest atomic commits per logical change
- You MUST NOT commit secrets, credentials, or sensitive data

---

## VII. Operational Excellence

### 6.1 State Management

**Standard**: All state MUST be managed remotely in HCP Terraform.

**Rules**:

- You MUST NOT generate local backend configurations
- Backend configuration typically empty for HCP Terraform CLI-driven workflow:

  ```hcl
  terraform {
    cloud {
      organization = "<org-name>"
      workspaces {
        name = "<workspace-name>"
      }
    }
  }
  ```

- State MUST never be committed to version control

### 6.2 Dependency Management

**Standard**: Provider and module versions MUST be explicitly constrained.

**Template**:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Rules**:

- Terraform minimum version is managed at the workspace level and MUST NOT be configured in code
- Provider versions MUST use pessimistic constraints (`~>`)
- You MUST NOT use `latest` or unconstrained versions

### 6.3 Cost Optimization

**Standard**: Generated infrastructure MUST consider cost implications.

**Rules**:

- You SHOULD prefer cost-effective resource types for non-production environments
- You MUST implement auto-scaling where applicable to optimize utilization
- You SHOULD include cost estimation reminders in documentation
- Idle resource cleanup SHOULD be considered for non-production environments

### 6.4 Monitoring and Observability

**Standard**: Infrastructure MUST be observable by default.

**Rules**:

- You SHOULD enable CloudWatch/monitoring when using AWS modules
- Tags MUST include monitoring metadata (`Environment`, `Owner`, `Application`)
- You SHOULD output critical resource identifiers for integration with monitoring systems

---

## VIII. Specification Management

### 7.1 Specification Creation and Storage

**Standard**: Specifications are first-class artifacts stored in version control alongside code.

**Specification Directory Structure**:

```
/
├── specs/
│   ├── SPEC-001-vpc-enhancement.md
│   ├── SPEC-002-database-migration.md
│   └── README.md (index of all specifications)
├── main.tf
├── variables.tf
└── ...
```

**Specification Naming Convention**:
- Format: `SPEC-###-short-title.md`
- Example: `SPEC-001-vpc-enhancement.md`, `SPEC-042-lambda-deployment.md`
- Increment counter sequentially
- Use lowercase with hyphens

**Specification Template**:

```markdown
# SPEC-001: VPC Enhancement for High Availability

**Status**: Draft | Approved | Implemented | Superseded
**Author**: Team Name
**Created**: YYYY-MM-DD
**Updated**: YYYY-MM-DD
**Specification ID**: SPEC-001

## Purpose
[Clear business objective and use case]

## Scope
[Affected resources and systems]

## Compliance Requirements
[Security, regulatory, organizational standards]

## Performance and Scalability
[Availability, throughput, and scaling requirements]

## Cost Constraints
[Budget and optimization expectations]

## Functional Requirements
1. [Requirement]
2. [Requirement]

## Technical Requirements
1. [Technical detail]
2. [Technical detail]

## Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Acceptance Tests
1. Test procedure 1
2. Test procedure 2

## Related Specifications
- SPEC-002 (Dependency)

## Implementation Notes
[Any additional context for implementers]

## Approval
- [ ] Product Owner
- [ ] Platform Team
- [ ] Security Team
```

### 7.2 Specification Validation

**Standard**: Specifications MUST be validated before implementation begins.

**Validation Checklist**:

- [ ] Specification has unique identifier (SPEC-###)
- [ ] Purpose is clear and business-aligned
- [ ] Scope is well-defined
- [ ] All compliance requirements documented
- [ ] Success criteria are measurable
- [ ] Acceptance tests are specific and testable
- [ ] No conflicting requirements within specification
- [ ] Dependencies on other specifications documented
- [ ] Cost implications considered
- [ ] Required approvals obtained

**Validation Process**:

1. Author creates specification document
2. Specification added to `/specs` directory
3. Specification review via pull request (feature → dev)
4. Stakeholders review and comment
5. Upon approval, specification merged to dev
6. Implementation can begin on approved specification

### 7.3 Specification Lifecycle

**Specification States**:

- **Draft**: Specification under development, not yet approved
- **Approved**: Specification reviewed and accepted for implementation
- **In-Progress**: Specification is being implemented (feature branch exists)
- **Implemented**: Code merged and deployed to dev
- **Staged**: Implementation in staging environment
- **Promoted**: Implementation in production
- **Superseded**: Replaced by newer specification
- **Archived**: No longer applicable

**Specification Updates**:

- Minor clarifications: Direct commits to specification
- Requirement changes: Create new specification, reference original
- Supersession: Mark original as "Superseded by SPEC-XXX"

### 7.4 Specification Traceability

**Standard**: Code MUST be traceable back to specifications.

**Implementation**:

- Every code block MUST reference its specification
- Branch names MUST include specification ID
- Pull requests MUST reference specification
- Comments MUST link code to specification sections

**Code Example**:

```hcl
# SPEC-001: Enable Flow Logs for Network Monitoring
# Requirement: Enable VPC Flow Logs for security compliance
# Success Criteria: VPC sends logs to CloudWatch Logs
resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Specification = "SPEC-001"
    Purpose       = "Network Monitoring"
  }
}
```

---

## IX. AI Agent Behavior and Constraints

### 9.1 Prerequisites Validation

**Constraint**: You MUST validate both specification and HCP Terraform prerequisites before any operations.

**Requirements**:

- The `/specify` command MUST always validate specification-driven prerequisites
- You MUST NOT proceed with code generation without an approved specification
- You MUST request a written specification before generating infrastructure code
- You MUST validate HCP Terraform configuration details from the current remote git repository
- Missing configuration details MUST be surfaced to the user with clear instructions
- All Terraform MCP server tool calls MUST use the validated configuration values

**Specification Prerequisites**:

- Specification document exists in `/specs` directory
- Specification has unique identifier (SPEC-###)
- Specification includes all required sections (purpose, scope, requirements, success criteria)
- Specification has been reviewed and approved
- Specification acceptance criteria are measurable and testable

**HCP Terraform Prerequisites**:

- HCP Terraform Organization Name
- HCP Terraform Project Name
- HCP Terraform Workspace Name for Dev environment
- HCP Terraform Workspace Name for Staging environment
- HCP Terraform Workspace Name for Prod environment

**Workflow**:

1. User provides or references specification (e.g., "Implement SPEC-001")
2. You MUST validate specification exists and is approved
3. You validate HCP Terraform configuration details
4. Proceed with code generation only when ALL prerequisites are met

### 9.2 Scope Boundaries

**Constraint**: You MUST operate within defined consumption patterns and honor specification-driven development.

**In Scope**:

- Reviewing and validating specifications for completeness and compliance
- Suggesting improvements to specifications before implementation
- Searching for and composing infrastructure from approved private modules using `search_private_modules` tool
- Generating code that strictly implements specification requirements
- Creating/updating feature branches with proper gitflow naming conventions
- Generating environment-specific variable definitions
- Creating and updating documentation with specification references
- Generating acceptance tests based on specification success criteria
- Suggesting workspace configuration
- Explaining Terraform concepts and specification-driven development practices
- Creating specification documents when not provided by user

**Out of Scope**:

- Generating code without an approved specification
- Creating new Terraform modules (platform team responsibility)
- Modifying or forking existing modules without explicit approval
- Bypassing policy controls or suggesting workarounds
- Direct resource creation without module encapsulation
- Workspace RBAC configuration (security team responsibility)
- Merging pull requests (human review required)
- Deleting long-lived branches (dev, staging, main)

### 9.3 Error Handling and Transparency

**Standard**: You MUST acknowledge limitations, uncertainties, and specification gaps.

**Rules**:

- You MUST refuse code generation requests that lack a written specification
- When no specification exists, you MUST help the user CREATE one before code generation
- When specifications are ambiguous or incomplete, you MUST request clarification before proceeding
- You MUST use `search_private_modules` tool to find appropriate modules before generating infrastructure code
- When multiple approaches exist, you MUST explain tradeoffs with specification reference
- When required modules don't exist in the private registry (confirmed via `search_private_modules`), you MUST NOT improvise with raw resources
- When policy violations are likely, you MUST warn users proactively
- When specification requirements conflict with security or compliance policies, you MUST highlight the conflict and request resolution
- You MUST document all assumptions made during implementation in code comments

### 9.4 Learning and Adaptation

**Standard**: You MUST learn from organizational patterns, specifications, and feedback.

**Implementation**:

- You SHOULD reference successful prior specifications and implementations as patterns
- You SHOULD suggest specification template improvements based on recurring questions
- You MUST respect organizational customizations to this constitution
- You SHOULD incorporate policy feedback to avoid repeated violations
- You SHOULD help teams refine specifications based on implementation learnings
- You MUST maintain traceability between specifications and implementations for continuous improvement

---

## X. Governance and Evolution

### 10.1 Constitution Updates

**Process**: This constitution evolves with organizational needs, including specification standards.

**Update Authority**:

- Platform team maintains constitution in version control
- Major changes require review by security and governance teams
- Application teams MAY propose amendments via pull request
- Specification best practices are incorporated into constitution updates
- Constitution version MUST be referenced in AI agent prompts

**Specification Standard Evolution**:

- Successful specification patterns are documented and shared
- Common specification gaps trigger constitution updates
- New compliance requirements prompt specification template updates

### 10.2 Exception Process

**Policy**: Deviations from constitution or specifications require explicit approval and documentation.

**Process for Specification Exceptions**:

1. Document specific specification requirement driving exception
2. Explain why specification requirement cannot be met
3. Propose alternative approach with risk assessment
4. Obtain product owner and platform team approval
5. Document exception in specification (mark as "Exception Granted")
6. Implement alternative with exception reference in code comments
7. Review exception and update specification template if pattern emerges

**Process for Constitution Exceptions**:

1. Document specific requirement driving exception
2. Propose alternative approach with risk assessment
3. Obtain platform team approval
4. Document exception in code and centralized exceptions register
5. Review exception during next policy update cycle

### 10.3 Audit and Compliance

**Standard**: AI-generated code and specifications are subject to same audits as human-authored code.

**Requirements**:

- All generated code MUST pass through policy enforcement
- All specifications MUST be approved before implementation
- Periodic audits verify:
  - Specification coverage (all infrastructure has supporting specification)
  - Code-specification traceability (code references its specification)
  - Compliance with specification requirements
  - Constitution compliance
- Non-compliant patterns trigger constitution updates or module improvements
- Specification gaps trigger process improvements
- Metrics track:
  - Module adoption rates
  - AI-generated code quality
  - Specification approval time
  - Code-specification traceability rates

### 10.4 Feedback Loop

**Standard**: Continuous improvement through systematic feedback on specifications, code, and processes.

**Mechanisms**:

- Application teams provide feedback on module usability and specification effectiveness
- Policy violations inform module design and specification template improvements
- Specification gaps drive specification standard refinements
- AI agent error patterns and specification issues drive documentation enhancements
- Implementation learnings inform specification best practices
- Adoption metrics guide platform team priorities
- Specification reuse patterns identify successful templates
- Specification exceptions drive constitution updates

---

## XI. Testing and Validation Framework

### 11.1 Specification-Driven Testing

**Standard**: All testing MUST validate that implementations meet specification requirements.

**Testing Strategy**:

- Tests MUST be based on specification success criteria
- Test procedures MUST be derived from specification acceptance tests
- Test results MUST document which specification requirements were validated
- Failed tests MUST be traced back to specific specification requirements

**Specification Validation Checklist**:

Before testing infrastructure, verify:
- [ ] Specification is approved
- [ ] Implementation code references specification ID
- [ ] Code comments link to specification sections
- [ ] Success criteria defined in specification
- [ ] Acceptance tests prepared from specification

### 11.2 Ephemeral Workspace Testing

**Standard**: All AI-generated Terraform code MUST be validated in ephemeral testing environments before promotion.

**Rationale**: Ephemeral workspaces provide safe, isolated environments for testing infrastructure changes without impacting existing environments or incurring long-term costs. Testing validates both code quality and specification compliance.

**Implementation Requirements**:

- You MUST create ephemeral HCP Terraform workspaces ONLY for testing AI-generated Terraform configuration code
- The current `feature/*` branch MUST be committed and pushed to the remote Git repository BEFORE creating the ephemeral workspace
- Ephemeral workspaces MUST be created within the current HCP Terraform Organization and Project
- Ephemeral workspace MUST be connected to the current `feature/*` branch of the application's GitHub remote repository to ensure code under test matches the current feature development state
- Ephemeral workspace MUST be created with "auto-apply API, UI and VCS runs" setting turned ON to enable automatic apply after successful plan without human confirmation
- Ephemeral workspace MUST be created with "Auto-Destroy" setting ON and configured to automatically delete after 2 hours
- You MUST create all necessary workspace variables at the ephemeral workspace level based on required variables defined in `variables.tf` in the `feature/*` branch
- Testing MUST include both `terraform plan` and `terraform apply` operations
- All testing activities MUST be performed automatically against the ephemeral workspace
- Upon successful testing, you MUST create corresponding workspace variables for the dev workspace
- Ephemeral workspaces will be automatically destroyed after 2 hours via auto-destroy setting

### 11.3 Automated Testing Workflow

**Standard**: Testing workflow MUST be fully automated using available Terraform MCP server tools and MUST validate specification compliance.

**Pre-Testing Specification Verification**:

1. Confirm specification exists and is approved
2. Extract success criteria from specification
3. Prepare acceptance tests from specification requirements
4. Document which specification requirements each test validates

**Testing Process**:

1. **Ephemeral Workspace Creation**:
   - Create ephemeral workspace using Terraform MCP server
   - Workspace name MUST follow pattern: `test-<app-name>-<timestamp>` or similar unique identifier
   - Workspace MUST be created in the specified HCP Terraform Organization and Project
   - Workspace MUST have "auto-apply API, UI and VCS runs" setting enabled (set `auto_apply` to `true`)
   - Workspace MUST have "Auto-Destroy" setting enabled with 2-hour duration (`auto_destroy_at` set to 2 hours from creation)

2. **Variable Configuration**:
   - Analyze `variables.tf` file in the `feature/*` branch to identify all required variables
   - Create workspace variables at the ephemeral workspace level using Terraform MCP server tools
   - Prompt user for variable values when not determinable (DO NOT guess values)
   - EXCLUDE cloud provider credentials (these are pre-configured at workspace level)
   - Include all application-specific and environment-specific variables
   - Document variable configuration for subsequent dev workspace setup

3. **Terraform Execution**:
   - Ensure
   - Run `terraform init`, then  `terraform plan` locally** - HCP Terraform VCS workflow handles these automatically
   - Create a Terraform run against the ephemeral workspace (via `create_run` with auto-apply enabled)
   - HCP Terraform will automatically execute `terraform init` and `terraform plan` as part of the run
   - Analyze plan output for potential issues or unexpected changes
   - Terraform apply will automatically start after successful plan due to auto-apply setting
   - Monitor apply operation for successful completion

4. **Result Analysis**:
   - Verify successful completion of terraform run
   - If errors occur, analyze output and provide specific remediation suggestions
   - Document any issues found and resolution steps taken
   - Upon successful testing, prompt user to validate the created resources
   - After user validation, create identical workspace variables for the dev workspace
   - Delete the ephemeral workspace to minimize costs (auto-destroy will handle cleanup if manual deletion is not performed)
   - Provide clear success/failure status to the user

### 11.4 Variable Management for Testing

**Standard**: Test workspace variables MUST be derived from generated configuration files and specification requirements.

**Variable Source Priority**:

1. **Specification**: Requirements for variable values and constraints
2. **variables.tf**: Primary source for identifying required variables, validation rules and type constraints
3. **User Input**: Values for application-specific variables (when not determinable)
4. **Workspace Variable Sets**: Pre-configured organizational standards (DO NOT duplicate)

**Variable Creation Rules**:

- You MUST create workspace variables for all required variables defined in variables.tf from the `feature/*` branch
- You MUST respect variable types and validation rules defined in variables.tf
- You MUST prompt user for values when they cannot be reasonably determined
- You MUST NOT create variables for cloud provider credentials (AWS keys, GCP service accounts, etc.)
- You SHOULD use sensible defaults for non-sensitive testing values where appropriate
- You MUST mark sensitive variables appropriately in the workspace
- Upon successful testing, you MUST create identical variables in the dev workspace

**Example Variable Handling**:

```hcl
# From variables.tf in feature/* branch
variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "database_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# Implementation:
# - environment: Set to "test" for ephemeral workspace
# - vpc_cidr: Prompt user for test CIDR value
# - database_password: Prompt user for test password (marked sensitive)
# - Upon success: Create identical variables in dev workspace
```

### 11.5 Error Analysis and Remediation

**Standard**: Test failures MUST be analyzed systematically with actionable remediation guidance and traced to specification requirements.

**Failure Analysis Process**:

1. **Plan Failures**:
   - Analyze terraform plan errors for configuration issues
   - Check for missing variables or invalid variable values
   - Verify module sources and version constraints
   - Validate provider configuration and authentication

2. **Apply Failures**:
   - Analyze resource creation errors for infrastructure constraints
   - Check for quota limits, permission issues, or resource conflicts
   - Verify network connectivity and security group configurations
   - Examine resource dependencies and ordering issues

3. **Validation Failures**:
   - Check terraform validation errors for syntax or configuration issues
   - Verify required provider versions and constraints
   - Validate variable types and constraint violations

**Remediation Guidance**:

- You MUST provide specific, actionable remediation steps for identified issues
- You SHOULD suggest code changes to resolve configuration problems
- You MUST distinguish between issues requiring code changes vs. workspace configuration
- You SHOULD provide alternative approaches when the original approach has fundamental issues

### 11.6 Testing Documentation Requirements

**Standard**: All testing activities MUST be documented for audit and troubleshooting purposes, including specification traceability.

**Documentation Requirements**:

- Specification ID MUST be documented (e.g., "Testing validates SPEC-001")
- Which specification requirements each test validates MUST be documented
- Testing process MUST be documented in the README.md
- Variable requirements MUST be clearly explained with specification context
- Prerequisites for testing MUST be listed
- Common testing issues and resolutions MUST be documented
- Acceptance criteria from specification MUST be included

**README Testing Section Template**:

```markdown
## Testing

This infrastructure code has been validated using ephemeral HCP Terraform workspaces.

### Prerequisites
- HCP Terraform organization and project access
- Required variable values (see terraform.tfvars.example)
- Terraform MCP server configured

### Testing Process
1. Ephemeral workspace created: `<workspace-name>`
2. Variables configured from terraform.tfvars.example
3. Terraform plan executed successfully
4. Terraform apply completed without errors

### Required Variables
- `environment`: Deployment environment
- `vpc_cidr`: VPC CIDR block for networking
- (Additional variables as identified)

### Common Issues
- (Document any issues encountered during testing)
```

### 11.7 Cleanup and Resource Management

**Standard**: Ephemeral testing resources MUST be properly cleaned up to avoid unnecessary costs.

**Cleanup Requirements**:

- Ephemeral workspaces have auto-destroy enabled as a safety mechanism (2 hours after creation)
- You MUST trigger workspace deletion after successful terraform apply AND user validation of resources
- Manual cleanup after validation minimizes costs and prevents unnecessary resource retention
- Auto-destroy serves as a failsafe if manual cleanup is not performed
- You MUST notify users that the ephemeral workspace will auto-destroy in 2 hours if not manually cleaned up
- If testing fails, workspace will still be destroyed after 2 hours but users are notified to review logs before destruction

**Cost Optimization**:

- Use minimal resource sizes for testing when possible
- Prefer regions with lower costs for ephemeral testing
- Document cost implications of extended testing periods
- Suggest cleanup schedules for development workflows

---

## XII. Task and Issue Management

### 12.1 GitHub Issues Integration

**Principle**: speckit.implement MUST manage all development tasks as GitHub issues to provide visibility, traceability, and collaboration for infrastructure development work.

**Rationale**: GitHub issues provide a centralized platform for task tracking, enabling better collaboration between AI agents, developers, and stakeholders. Issues create an auditable trail of development activities, facilitate discussion, and integrate seamlessly with pull requests and git workflows.

**Implementation Requirements**:

**Access Control**:
- speckit.implement MUST have read/write access to GitHub Issues API
- Repository MUST have Issues enabled in repository settings
- Authentication MUST use GitHub Personal Access Token (PAT) with `repo` scope or GitHub App with appropriate permissions
- Credentials MUST be securely stored and never committed to version control

**Issue Creation**:
- speckit.implement MUST create a GitHub issue for each discrete task identified during specification implementation
- Issues MUST include:
  - **Title**: Clear, actionable task description (e.g., "Implement VPC module for dev environment")
  - **Description**: Detailed task requirements, acceptance criteria, and specification reference
  - **Labels**: Appropriate labels for categorization (e.g., `infrastructure`, `terraform`, `speckit`, specification ID)
  - **Specification Link**: Reference to the driving specification document
  - **Dependencies**: Links to related issues or blockers
- Issue body MUST follow this template:

```markdown
## Task Description
[Detailed description of the task]

## Specification Reference
- **Spec ID**: SPEC-XXX
- **Spec Link**: [Link to specification document]
- **Spec Section**: [Relevant section]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Implementation Notes
[Any relevant technical notes or considerations]

## Related Issues
- Related to #XX
- Depends on #YY
- Blocks #ZZ
```

**Issue Lifecycle Management**:

1. **Issue Creation** (Initial Task Identification):
   - Create issue when task is identified from specification
   - Assign labels: `speckit`, `todo`, specification ID (e.g., `spec-001`)
   - Link to parent specification or epic if applicable

2. **Issue Assignment** (Work Begins):
   - Update issue status when work begins
   - Add `in-progress` label
   - Comment on issue with implementation approach or questions
   - Reference the feature branch being created

3. **Issue Progress Updates**:
   - Comment on issue for significant progress milestones
   - Update checklist items in issue description as completed
   - Tag stakeholders for review or input when needed
   - Document any blockers or challenges encountered

4. **Issue Closure** (Task Completion):
   - Close issue when task is complete and merged
   - Reference the closing pull request using keywords: `Closes #XX`, `Fixes #XX`, or `Resolves #XX`
   - Add `completed` label
   - Verify all acceptance criteria are met before closing

**Issue Linking and Traceability**:

- Every feature branch MUST reference its issue number in the branch name: `feature/123-description`
- Every commit SHOULD reference related issues: `feat: implement vpc module (ref #123)`
- Pull requests MUST reference issues they address: `Closes #123`
- Specification documents MUST reference related issues when they exist

**Issue Labels and Organization**:

Required labels:
- `speckit` - All issues created by speckit.implement
- `infrastructure` - Infrastructure-related tasks
- `terraform` - Terraform code development
- `spec-XXX` - Specification identifier
- `todo` - Not yet started
- `in-progress` - Currently being worked on
- `blocked` - Waiting on dependencies
- `review` - Ready for review
- `completed` - Task finished

Optional labels:
- `bug` - Bug fixes
- `enhancement` - Feature additions
- `documentation` - Documentation updates
- `testing` - Testing-related tasks
- `security` - Security-related work
- `priority:high` / `priority:medium` / `priority:low` - Priority levels

**Issue Templates**:

Repository SHOULD include issue templates for common task types:
- Infrastructure Task (`.github/ISSUE_TEMPLATE/infrastructure-task.md`)
- Bug Report (`.github/ISSUE_TEMPLATE/bug-report.md`)
- Module Request (`.github/ISSUE_TEMPLATE/module-request.md`)
- Specification Implementation (`.github/ISSUE_TEMPLATE/spec-implementation.md`)

**Automation and Integration**:

- GitHub Actions MAY be configured to automatically:
  - Apply labels based on branch names or file paths
  - Update issue status based on pull request state
  - Post test results to related issues
  - Notify stakeholders of issue state changes
- Project boards MAY be used to visualize issue workflow
- Milestones SHOULD group related issues by specification or release

**Reporting and Metrics**:

- speckit.implement SHOULD track:
  - Number of issues created per specification
  - Average time from issue creation to closure
  - Number of blocked issues and resolution time
  - Issue completion rate
- Weekly summaries MAY be posted as comments on specification issues

**Error Handling and Issue Recovery**:

- If issue creation fails, speckit.implement MUST log the error and retry
- Failed API calls MUST be documented in `tool_errors_output.log`
- Issues orphaned by failed operations SHOULD be identified and cleaned up
- Manual issue creation fallback MUST be available if automation fails

**Best Practices**:

- Keep issues focused on single, discrete tasks (small scope)
- Use clear, descriptive titles without jargon
- Update issues promptly with progress and blockers
- Link related issues to provide context
- Use issue comments for discussions rather than external channels
- Archive or close stale issues after 30 days of inactivity
- Use issue templates to maintain consistency

### 12.2 Jira CLI Integration

**Principle**: When using Jira as the primary issue tracking system, speckit.implement MUST manage all development tasks as Jira issues using the Jira CLI to provide visibility, traceability, and programmatic automation for infrastructure development work.

**Rationale**: Jira provides enterprise-grade issue tracking with workflow automation, custom fields, and integration capabilities. The Jira CLI enables programmatic access to Jira operations, enabling AI agents to automate task management while maintaining consistency with organizational processes. CLI access provides a scriptable alternative to GitHub Issues for organizations with existing Jira investments.

**Installation and Setup**:

- Jira CLI MUST be installed and available in the development environment
- Installation: `brew install jira-cli` (macOS) or `npm install -g jira-cli` (alternative)
- Configuration file MUST be created at `~/.jira` or environment variable `JIRA_CONFIG`
- Jira instance URL, username, and API token MUST be configured securely
- API token MUST NOT be committed to version control
- Configuration SHOULD use environment variables for sensitive values:
  - `JIRA_HOST`: Jira instance URL (e.g., `https://org.atlassian.net`)
  - `JIRA_USER`: Jira username or email
  - `JIRA_TOKEN`: API token (generated from Jira Account Settings)
  - `JIRA_PROJECT`: Default project key for issue operations

**Access Control**:

- speckit.implement MUST have Jira API token with appropriate permissions
- Token MUST have permissions to: view issues, create issues, edit issues, transition issues, add comments
- Token MUST NOT have administrative or deletion permissions
- Credentials MUST be securely stored in environment variables or credential manager
- Credentials MUST never be committed to version control or logged in output
- API token scope MUST be limited to required operations only

**Issue Creation via Jira CLI**:

- speckit.implement MUST create a Jira issue for each discrete task identified during specification implementation
- Issues MUST be created with the `jira create` command
- Issues MUST include:
  - **Summary**: Clear, actionable task description (e.g., "Implement VPC module for dev environment")
  - **Description**: Detailed task requirements, acceptance criteria, and specification reference
  - **Issue Type**: e.g., Feature, Task, Story (match organizational standards)
  - **Project**: Project key matching the repository (e.g., "INFRA", "TF", "AWS")
  - **Labels**: Appropriate labels for categorization (e.g., `infrastructure`, `terraform`, `speckit`, specification ID)
  - **Custom Fields**: Organization-specific fields (e.g., `Specification ID`, `Cost Impact`)
  - **Parent Issue** (Epic): Link to parent specification epic if applicable

**Jira CLI Command Examples**:

```bash
# Create a new task with specification reference
jira create \
  --project INFRA \
  --type Task \
  --summary "Implement VPC module for dev environment" \
  --description "Specification: SPEC-001

Detailed implementation of VPC infrastructure module for development environment.

Acceptance Criteria:
- VPC created with specified CIDR block
- Flow logs enabled for network monitoring
- Tags applied per organizational standards

See specification: /specs/SPEC-001.md" \
  --label infrastructure \
  --label terraform \
  --label spec-001 \
  --assignee current_user

# Transition issue to In Progress
jira transition "INFRA-123" --resolution "In Progress"

# Add comment documenting progress
jira comment "INFRA-123" "Implementation started on feature/123-vpc-module. PR: #456"

# Update issue with acceptance test results
jira edit "INFRA-123" --comment "Acceptance tests passed. Testing validates:
- VPC created with 10.0.0.0/16 CIDR
- Flow logs configured for CloudWatch Logs
- Tags applied: Environment=dev, ManagedBy=terraform"

# Close issue
jira transition "INFRA-123" --resolution "Done"
```

**Issue Lifecycle Management**:

1. **Issue Creation** (Initial Task Identification):
   - Create issue using `jira create` command when task is identified from specification
   - Assign to `speckit.implement` user or workflow group
   - Set status to `To Do`
   - Apply labels: `speckit`, `infrastructure`, specification ID (e.g., `spec-001`)
   - Link to parent epic or specification issue if applicable

2. **Issue Assignment** (Work Begins):
   - Update issue status to `In Progress` using `jira transition`
   - Add comment documenting the feature branch being created
   - Reference Jira issue key in git branch: `feature/INFRA-123-vpc-module`
   - Reference issue in initial commit: `feat: start INFRA-123 vpc module implementation`

3. **Issue Progress Updates**:
   - Use `jira comment` to document significant progress milestones
   - Update acceptance criteria checklist in description as items complete
   - Use `jira edit` to update custom fields (e.g., estimated cost, resource count)
   - Tag stakeholders in comments for review or input when needed
   - Document blockers or challenges in issue comments

4. **Issue Closure** (Task Completion):
   - Transition issue to `Done` or `Resolved` when task complete and merged
   - Add final comment referencing the merged pull request
   - Verify all acceptance criteria are met before closing
   - Include validation results and deployment confirmation
   - Archive or link to follow-up issues if needed

**Issue Linking and Traceability**:

- Every feature branch MUST reference its Jira issue key in branch name: `feature/INFRA-123-description`
- Every commit SHOULD reference related Jira issues: `feat: implement vpc module (ref INFRA-123)`
- Pull requests MUST reference Jira issues they address (GitHub PR will link to Jira via bot or manual link)
- Specification documents MUST reference related Jira issues when they exist
- Jira issues MUST include specification link in description for bidirectional traceability

**Jira Fields and Organization**:

Standard issue type: `Task`

Recommended custom fields:
- `Specification ID`: Link to driving specification (SPEC-001, SPEC-002, etc.)
- `Terraform Module`: Module being implemented (module name or URL)
- `Environment`: Deployment environment (dev, staging, prod)
- `Cost Impact`: Estimated costs (for financial tracking)
- `Resource Count`: Number of resources being created

Required labels:
- `speckit` - All issues created by speckit.implement
- `infrastructure` - Infrastructure-related tasks
- `terraform` - Terraform code development
- `spec-XXX` - Specification identifier
- Any organizational-specific labels

Standard workflow transitions:
- `To Do` → `In Progress`: When work begins
- `In Progress` → `In Review`: When pull request is created
- `In Review` → `Done`: When merged to target branch
- Any state → `Blocked`: When waiting on dependencies

**Issue Query Examples**:

```bash
# List all in-progress speckit tasks for current sprint
jira list --project INFRA --label speckit --status "In Progress"

# Find all issues blocking deployment
jira list --project INFRA --label terraform --status Blocked

# Get details of specific issue
jira view INFRA-123

# List all issues for specification SPEC-001
jira list --project INFRA --label spec-001
```

**Automation and Integration**:

- CLI scripts MAY be created to automate common operations:
  - Auto-create issues from specification documents
  - Bulk transition issues when pull requests are merged
  - Post test results to issue comments
  - Create follow-up issues from specification sections

- Webhooks or scripts MAY listen for:
  - Git push events to auto-transition issues to `In Progress`
  - Pull request merges to auto-transition issues to `Done`
  - Failed CI/CD runs to comment on related issues

- Integration patterns:
  - Issue key in git branch → automation identifies related issue
  - Commit messages reference issue key → Jira auto-links commits
  - Pull request references issue → cross-links in both systems
  - Merged PR triggers issue transition → automatic status update

**Error Handling and Recovery**:

- If issue creation fails via CLI, speckit.implement MUST log the error and retry
- Failed API calls MUST be documented in `tool_errors_output.log` with:
  - Command attempted (with sensitive data redacted)
  - Error message and error code
  - Number of retry attempts
  - Resolution steps taken

- Common error patterns and resolutions:
  - `Connection refused`: Check JIRA_HOST is correct and accessible
  - `Authentication failed`: Verify JIRA_USER and JIRA_TOKEN are correct
  - `Project not found`: Confirm JIRA_PROJECT key is correct
  - `Invalid transition`: Verify target status is valid for current workflow

- Fallback procedures:
  - Manual issue creation in Jira UI if CLI fails
  - Batch retry of failed operations once connectivity restored
  - Document failed operations with timestamps for manual review

**CLI Security Best Practices**:

- API token MUST be stored in environment-specific config, not in repository
- Example `.zshrc` or `.bashrc` configuration:
  ```bash
  export JIRA_HOST="https://org.atlassian.net"
  export JIRA_USER="your-email@org.com"
  export JIRA_PROJECT="INFRA"
  # JIRA_TOKEN should come from secure credential manager
  export JIRA_TOKEN=$(pass show jira/api-token 2>/dev/null || echo "")
  ```

- Never pipe sensitive data through logs or debugging output
- Clear command history that contains credentials: `history -c`
- Rotate API tokens periodically (at least annually)

**GitHub-Jira Interoperability**:

When both GitHub and Jira are in use:

- GitHub issues MAY be used for public discussions and community contributions
- Jira issues MUST be used for internal infrastructure task tracking
- Branch naming MUST reference Jira issue key (primary tracking system)
- GitHub PR SHOULD include comment linking to Jira issue for cross-reference
- Specification traceability follows Jira issue, with GitHub PR as secondary link
- Automated sync MAY be configured to mirror issue state between systems
- Status of record: Jira (source of truth), GitHub (informational link)

**Best Practices**:

- Keep issues focused on single, discrete tasks (small scope)
- Use clear, descriptive summaries without jargon
- Include specification reference in all issue descriptions
- Update issues promptly with progress, blockers, and questions
- Use standard transitions for consistent workflow tracking
- Close issues only when acceptance criteria verified
- Include measurement results (costs, resources, time) in issue comments
- Use bulk operations for consistency (e.g., transition all spec-X issues when spec approved)

---

## XIII. Implementation Checklist

### For Application Teams Using AI Agents

**Specification-First Workflow**:

- [ ] Clone validated pattern template repository
- [ ] Review this constitution with your team
- [ ] Select issue tracking system: GitHub Issues or Jira (or both for hybrid environments)
- [ ] Enable GitHub Issues in repository settings (if using GitHub)
- [ ] Configure GitHub Issues access for speckit.implement (PAT or GitHub App with repo scope) (if using GitHub)
- [ ] Configure Jira CLI access for speckit.implement (API token with appropriate scope) (if using Jira)
- [ ] Create Jira project key matching repository if using Jira (e.g., INFRA, TF, AWS)
- [ ] Set up required labels and custom fields in Jira (if using Jira)
- [ ] Create specification document in `/specs` directory (SPEC-001, SPEC-002, etc.)
- [ ] Include all specification sections: purpose, scope, compliance, requirements, success criteria
- [ ] Review specification with stakeholders
- [ ] Obtain approval from product owner and platform team
- [ ] Commit specification to dev branch

**Implementation Workflow**:

- [ ] Create or review issue (GitHub or Jira) for the task with specification reference
- [ ] Create feature branch with issue number and specification ID: `feature/123-spec-001-description` (GitHub) or `feature/INFRA-123-spec-001-description` (Jira)
- [ ] Update issue with `in-progress` status and feature branch reference
- [ ] Use `search_private_modules` tool to identify required modules from private registry
- [ ] Configure IDE with AI assistant (Copilot, Claude Code, etc.)
- [ ] Generate Terraform code following specification requirements
- [ ] Add inline comments linking code to specification sections
- [ ] Validate code with `terraform validate` and `terraform fmt` (note: do NOT run `terraform init` or `terraform plan` locally)
- [ ] Update issue with progress comments
- [ ] Commit code with message: `feat: Implement SPEC-001 - Description (ref #123)` (GitHub) or `feat: Implement SPEC-001 - Description (ref INFRA-123)` (Jira)
- [ ] Push feature branch to remote

**Testing and Promotion Workflow**:

- [ ] Create pull request from feature branch to dev with specification and issue reference (e.g., "Closes #123" for GitHub or "Closes INFRA-123" for Jira)
- [ ] Verify acceptance criteria from specification in PR description
- [ ] Ensure human review validates code matches specification
- [ ] Upon approval, merge feature branch and delete it (GitHub issue auto-closes via PR merge; for Jira, manually transition to Done)
- [ ] Commit and push to trigger HCP Terraform VCS workflow
- [ ] Review plan output in HCP Terraform UI
- [ ] Deploy to dev environment and validate against specification success criteria
- [ ] Comment on closed issue with deployment results
- [ ] Create PR from dev to staging for promotion
- [ ] Upon staging sign-off, create PR from staging to main
- [ ] Progress through production with approval gates
- [ ] Keep track of any tool call errors and write the errors out to tool_errors_output.log with the details, provide the solution if the tool call was fixed by a subsequent call

### For Platform Teams

- [ ] Publish this constitution to organization knowledge base
- [ ] Create starter templates embodying these principles
- [ ] Select and configure issue tracking system: GitHub Issues, Jira, or both
- [ ] Enable GitHub Issues on all infrastructure repositories (if using GitHub)
- [ ] Configure GitHub Issue templates for common task types (if using GitHub)
- [ ] Set up required labels (`speckit`, `infrastructure`, `terraform`, etc.) in GitHub (if using GitHub)
- [ ] Configure GitHub Actions for automated issue management (optional, if using GitHub)
- [ ] Provide GitHub access credentials for speckit.implement (if using GitHub)
- [ ] Create GitHub Project boards for issue visualization (optional, if using GitHub)
- [ ] Configure Jira project templates and workflows for infrastructure teams (if using Jira)
- [ ] Set up required labels and custom fields in Jira (if using Jira)
- [ ] Provide Jira API token and CLI access for speckit.implement (if using Jira)
- [ ] Create Jira automation rules for issue transitions and notifications (if using Jira)
- [ ] Configure Jira webhooks for GitHub PR linkage (if using both systems)
- [ ] Document module catalog with usage examples
- [ ] Configure workspace-level security policies and controls
- [ ] Establish workspace provisioning workflow
- [ ] Create variable sets for common organizational config
- [ ] Monitor module adoption and AI-generated code quality
- [ ] Iterate on modules based on consumption patterns

---

## XIV. References and Resources

### Internal Resources

- Specification Directory: `/specs` (stored in repository)
- Specification Template: `specs/README.md`
- Private Module Registry: `app.terraform.io/<org-name>/modules`
- Policy Repository: `<policy-repo-url>`
- Platform Team Contact: `<platform-team-contact>`

### Specification Resources

- [GitHub Spec-Kit](https://github.com/github/spec-kit) - Specification-driven development framework
- [OpenAPI Specification](https://www.openapis.org/) - Specification standards
- [Arc42 Architecture Documentation](https://arc42.org/) - Architecture specification templates

### External Resources

- [Terraform Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)
- [HashiCorp Style Guide](https://developer.hashicorp.com/terraform/language/style)
- [Gitflow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)
- [AWS Terraform Provider Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/)
- [Azure Terraform Best Practices](https://docs.microsoft.com/en-us/azure/developer/terraform/best-practices)
- [Google Cloud Terraform Best Practices](https://cloud.google.com/docs/terraform/best-practices-for-terraform)
- [Jira CLI Documentation](https://github.com/ankitpokhrel/jira-cli)
- [Jira REST API](https://developer.atlassian.com/cloud/jira/rest/v3)
- [Jira API Token Generation](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/)

### Change Log

- **v2.2.0** (February 2026): Added Jira CLI integration and hybrid tracking support
  - Enhancement: Jira CLI integration as alternative to GitHub Issues
  - Enhancement: Jira-specific CLI commands and scripting patterns
  - Enhancement: GitHub-Jira interoperability guidance for hybrid environments
  - Enhancement: Jira security best practices and error handling
  - Enhancement: Updated implementation checklists for both platforms
  - Enhancement: Specification traceability across GitHub and Jira systems
- **v2.1.0** (January 2026): Added GitHub Issues integration for task management
  - Requirement: speckit.implement MUST manage all tasks as GitHub issues
  - Requirement: Issues MUST include specification references and traceability
  - Requirement: Issue lifecycle management (Creation → Assignment → Progress → Closure)
  - Enhancement: Issue templates for common infrastructure task types
  - Enhancement: Issue labeling and organization standards
  - Enhancement: Automated issue linking with branches, commits, and pull requests
  - Enhancement: Error handling and recovery for issue management operations
- **v2.0.0** (January 2026): Added specification-driven development and gitflow branch naming strategies
  - Requirement: Infrastructure code MUST be driven by written specifications
  - Requirement: Gitflow branching model with standardized naming conventions
  - Requirement: Specification traceability in all code and pull requests
  - Requirement: Specification lifecycle management (Draft → Approved → Implemented → Promoted)
  - Enhancement: Specification validation checklist and template
  - Enhancement: Code-specification traceability mechanisms
  - Enhancement: Testing validates specification success criteria
- **v1.0.0** (October 2025): Initial constitution release
