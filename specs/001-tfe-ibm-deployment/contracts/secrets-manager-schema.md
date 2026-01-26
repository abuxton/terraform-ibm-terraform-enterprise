# Secrets Manager Schema Contract

**Feature**: Terraform Enterprise on IBM Cloud (HVD)  
**Date**: 2026-01-26

## Overview

This document defines the required structure and format for all secrets that must be created in IBM Cloud Secrets Manager before deploying the TFE module. The module reads these secrets at deployment time but does NOT create or manage them (to avoid circular dependencies).

---

## Secret Creation Responsibility

**User Responsibility** (before running `terraform apply`):
1. Create IBM Cloud Secrets Manager instance
2. Create all required secrets in Secrets Manager
3. Provide secret CRNs as module input variables

**Module Responsibility** (during `terraform apply`):
1. Validate secret CRN format
2. Create IAM authorization policy for VSI to read secrets
3. Configure VSI user data script to retrieve secrets

**Module Does NOT**:
- Create secrets (must exist before deployment)
- Rotate secrets (user handles externally)
- Validate secret content (only format validation)

---

## Required Secrets

### 1. TFE License File

**Variable**: `tfe_license_secret_crn`  
**Secret Type**: `arbitrary`  
**Required**: ✅ Always

**Description**: Terraform Enterprise license file in HashiCorp License format (`.hclic`).

**Format**:
```json
{
  "secret_type": "arbitrary",
  "name": "tfe-license",
  "description": "TFE license file for prod-tfe deployment",
  "secret_group_id": "default",
  "payload": "<BASE64_ENCODED_HCLIC_CONTENT>"
}
```

**Payload Requirements**:
- Must be valid `.hclic` file from HashiCorp sales
- Must be base64-encoded before storing in Secrets Manager
- License must not be expired
- License must allow the configured number of users/workspaces

**Example Creation** (IBM Cloud CLI):
```bash
# Base64 encode license file
LICENSE_B64=$(base64 -i terraform.hclic)

# Create secret
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-license" \
  --description "TFE production license" \
  --payload "$LICENSE_B64" \
  --output json

# Extract CRN
CRN=$(ibmcloud secrets-manager secret --secret-id <secret-id> --output json | jq -r '.crn')
```

**Validation**:
- Module validates CRN format: `^crn:v1:bluemix:public:secrets-manager:`
- Module does NOT validate license content
- TFE application validates license at startup (deployment fails if invalid)

**Rotation**:
- When license approaches expiration, upload new license to same secret (updates `payload`)
- Restart TFE instances to load new license (manual operation)

---

### 2. TLS Certificate

**Variable**: `tls_certificate_secret_crn`  
**Secret Type**: `arbitrary`  
**Required**: ✅ Always

**Description**: TLS/SSL certificate for HTTPS access to TFE. Must match the configured `tfe_hostname`.

**Format**:
```json
{
  "secret_type": "arbitrary",
  "name": "tfe-tls-certificate",
  "description": "TLS certificate for tfe.example.com",
  "secret_group_id": "default",
  "payload": "-----BEGIN CERTIFICATE-----\nMIIE...\n-----END CERTIFICATE-----"
}
```

**Payload Requirements**:
- PEM format (base64-encoded X.509 certificate)
- Common Name (CN) or Subject Alternative Name (SAN) must match `tfe_hostname`
  - Example: CN=tfe.example.com or SAN includes tfe.example.com
- Certificate must be valid (not expired)
- Certificate chain:
  - **Full chain required**: Include intermediate certificates
  - Order: Server cert → Intermediate CA(s) → Root CA
  - Root CA optional if present in system trust store

**Example Full Chain**:
```
-----BEGIN CERTIFICATE-----
[Server Certificate for tfe.example.com]
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
[Intermediate CA Certificate]
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
[Root CA Certificate - optional]
-----END CERTIFICATE-----
```

**Example Creation**:
```bash
# Concatenate certificate chain
cat server.crt intermediate.crt root.crt > fullchain.pem

# Create secret (no base64 encoding needed for PEM)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-tls-certificate" \
  --payload "$(cat fullchain.pem)" \
  --output json
```

**Validation**:
- Module validates CRN format only
- IBM Cloud Load Balancer validates certificate format at deployment time
- TFE does NOT validate certificate (LB handles TLS termination)

**Rotation**:
- When certificate approaches expiration (30 days recommended):
  1. Upload new certificate to same secret
  2. Update load balancer configuration: `terraform apply` (no VSI restart needed)
  3. Verify new certificate via `openssl s_client -connect tfe.example.com:443`

---

### 3. TLS Private Key

**Variable**: `tls_private_key_secret_crn`  
**Secret Type**: `arbitrary`  
**Required**: ✅ Always

**Description**: Private key corresponding to TLS certificate. Used by load balancer for SSL termination.

**Format**:
```json
{
  "secret_type": "arbitrary",
  "name": "tfe-tls-private-key",
  "description": "TLS private key for tfe.example.com",
  "secret_group_id": "default",
  "payload": "-----BEGIN RSA PRIVATE KEY-----\nMIIE...\n-----END RSA PRIVATE KEY-----"
}
```

**Payload Requirements**:
- PEM format (base64-encoded private key)
- Supported key types:
  - RSA (2048-bit or 4096-bit recommended)
  - ECDSA (P-256, P-384, P-521 curves)
- **Must match TLS certificate** (public/private key pair)
- **No passphrase** (IBM Cloud Load Balancer does not support encrypted keys)

**Example Creation**:
```bash
# If private key has passphrase, remove it first
openssl rsa -in encrypted-key.pem -out key.pem

# Create secret
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-tls-private-key" \
  --payload "$(cat key.pem)" \
  --output json
```

**Security Considerations**:
- ⚠️ **High Sensitivity**: Private key compromise allows man-in-the-middle attacks
- Use restrictive secret group permissions (limit to deployment service ID only)
- Enable Activity Tracker to audit all secret access
- Consider Hardware Security Module (HSM) storage for maximum security

**Validation**:
- Module validates CRN format only
- IBM Cloud Load Balancer validates key matches certificate at deployment time
- Test key/cert match before deployment:
  ```bash
  # Certificate modulus
  openssl x509 -noout -modulus -in server.crt | md5sum
  
  # Private key modulus (must match)
  openssl rsa -noout -modulus -in key.pem | md5sum
  ```

**Rotation**:
- Rotate together with TLS certificate (same process)

---

### 4. TFE Encryption Password

**Variable**: `tfe_encryption_password_secret_crn`  
**Secret Type**: `arbitrary`  
**Required**: ✅ Always

**Description**: TFE internal encryption password for vault encryption. Used by TFE application to encrypt sensitive data at rest.

**Format**:
```json
{
  "secret_type": "arbitrary",
  "name": "tfe-encryption-password",
  "description": "TFE vault encryption password",
  "secret_group_id": "default",
  "payload": "<RANDOM_STRING_32_PLUS_CHARACTERS>"
}
```

**Payload Requirements**:
- Minimum 16 characters (32+ characters recommended)
- High entropy (use cryptographically secure random generator)
- Allowed characters: `A-Z`, `a-z`, `0-9`, `!@#$%^&*()_+-=`
- **Store securely**: Losing this password makes TFE data unrecoverable

**Example Generation**:
```bash
# Generate 32-character random password
ENCRYPTION_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Create secret
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-encryption-password" \
  --payload "$ENCRYPTION_PASSWORD" \
  --output json
```

**Security Considerations**:
- ⚠️ **Critical Secret**: Never log or expose this password
- Cannot be rotated without data migration (TFE does not support password rotation)
- Backup password to secure offline location (disaster recovery)

**Validation**:
- Module validates CRN format only
- TFE application validates password strength at startup (fails if too weak)

**Disaster Recovery**:
- If password is lost, TFE data (workspace variables, sentinel policies) is unrecoverable
- Database and Object Storage backups are useless without this password

---

### 5. Database Admin Password

**Variable**: `database_admin_password_secret_crn`  
**Secret Type**: `arbitrary`  
**Required**: ✅ Always

**Description**: PostgreSQL admin user password for TFE database connection.

**Format**:
```json
{
  "secret_type": "arbitrary",
  "name": "tfe-database-password",
  "description": "PostgreSQL admin password for TFE database",
  "secret_group_id": "default",
  "payload": "<RANDOM_STRING_20_PLUS_CHARACTERS>"
}
```

**Payload Requirements**:
- Minimum 15 characters (20+ recommended)
- Must contain: uppercase, lowercase, number, special character
- Allowed special characters: `!@#$%^&*()_+-=[]{}|;:,.<>?`
- **Prohibited characters**: Single quote `'`, double quote `"`, backtick `` ` `` (SQL injection risk)

**Example Generation**:
```bash
# Generate 24-character password meeting complexity requirements
DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | head -c 24)

# Create secret
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-database-password" \
  --payload "$DB_PASSWORD" \
  --output json
```

**Usage by Module**:
```hcl
# Module provides password to IBM Cloud Databases
resource "ibm_database" "postgresql" {
  adminpassword = data.ibm_sm_secret.db_password.payload
  # ...
}

# Connection string includes password (marked sensitive)
output "database_connection_string" {
  value     = ibm_database.postgresql.connectionstrings[0].composed
  sensitive = true
}
```

**Rotation**:
- Supported via IBM Cloud Databases API:
  1. Update password in Secrets Manager
  2. Use `ibmcloud cdb user-password` to rotate database password
  3. Restart TFE instances to pick up new password
- **Downtime**: Brief connection interruption during rotation

---

### 6. Redis Password (Active-Active Only)

**Variable**: `redis_password_secret_crn`  
**Secret Type**: `arbitrary`  
**Required**: ⚠️ Only if `tfe_operational_mode = "active-active"`

**Description**: Redis admin password for distributed caching and locking.

**Format**:
```json
{
  "secret_type": "arbitrary",
  "name": "tfe-redis-password",
  "description": "Redis admin password for TFE active-active mode",
  "secret_group_id": "default",
  "payload": "<RANDOM_STRING_20_PLUS_CHARACTERS>"
}
```

**Payload Requirements**:
- Same as database password requirements
- Minimum 15 characters (20+ recommended)
- Complexity: uppercase, lowercase, number, special character

**Example Generation**:
```bash
REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | head -c 24)

ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-redis-password" \
  --payload "$REDIS_PASSWORD" \
  --output json
```

**Validation**:
- Module validates: If `tfe_operational_mode = "active-active"`, this secret MUST be provided
- Module validation error if active-active enabled but Redis password missing

**Rotation**:
- Same process as database password rotation
- Requires TFE instance restart to pick up new password

---

## Optional Secrets

### 7. Custom CA Bundle

**Variable**: `ca_bundle_secret_crn`  
**Secret Type**: `arbitrary`  
**Required**: ❌ Optional (only for private CA environments)

**Description**: Custom Certificate Authority bundle for environments using private/internal CAs.

**Format**:
```json
{
  "secret_type": "arbitrary",
  "name": "tfe-ca-bundle",
  "description": "Custom CA certificates for TFE to trust internal services",
  "secret_group_id": "default",
  "payload": "-----BEGIN CERTIFICATE-----\n[Private CA 1]\n-----END CERTIFICATE-----\n-----BEGIN CERTIFICATE-----\n[Private CA 2]\n-----END CERTIFICATE-----"
}
```

**Use Cases**:
- Enterprise environments with internal Certificate Authority
- VCS integration with self-signed certificates
- Private container registries with custom TLS certificates

**Example**:
```bash
# Concatenate all private CA certificates
cat internal-ca.crt company-root-ca.crt > ca-bundle.pem

ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name "tfe-ca-bundle" \
  --payload "$(cat ca-bundle.pem)" \
  --output json
```

---

### 8. Object Storage HMAC Credentials (if using HMAC auth)

**Variables**: 
- `cos_hmac_access_key_secret_crn`
- `cos_hmac_secret_key_secret_crn`

**Secret Type**: `arbitrary`  
**Required**: ⚠️ Only if `ObjectStorageBucket.auth_method = "hmac"`

**Description**: IBM Cloud Object Storage HMAC credentials for legacy authentication method.

**Format**:
```json
// Access Key
{
  "secret_type": "arbitrary",
  "name": "tfe-cos-access-key",
  "payload": "<HMAC_ACCESS_KEY_ID>"
}

// Secret Key
{
  "secret_type": "arbitrary",
  "name": "tfe-cos-secret-key",
  "payload": "<HMAC_SECRET_ACCESS_KEY>"
}
```

**Recommendation**: Use IAM authentication instead (more secure, automatic credential rotation)

---

## Secret Group Organization

### Recommended Structure

```
Secrets Manager Instance
└── Secret Groups
    ├── tfe-production/          # Production TFE secrets
    │   ├── tfe-license
    │   ├── tfe-tls-certificate
    │   ├── tfe-tls-private-key
    │   ├── tfe-encryption-password
    │   ├── tfe-database-password
    │   └── tfe-redis-password
    │
    ├── tfe-staging/             # Staging TFE secrets
    │   ├── tfe-license (same as prod)
    │   ├── tfe-tls-certificate (staging cert)
    │   └── ...
    │
    └── tfe-development/         # Dev TFE secrets
        └── ...
```

**Benefits**:
- Logical separation by environment
- Different IAM policies per environment
- Easier secret rotation management

---

## IAM Authorization Policy

### Required Policy

Module creates this policy automatically:

```hcl
resource "ibm_iam_authorization_policy" "vsi_to_secrets" {
  source_service_name         = "is"
  source_resource_type        = "instance"
  target_service_name         = "secrets-manager"
  target_resource_instance_id = var.secrets_manager_instance_id
  roles                       = ["SecretsReader"]
}
```

**Effect**: All TFE VSI instances can read secrets from specified Secrets Manager instance.

**Security Consideration**: VSI instances can read ALL secrets in the instance. To restrict:
1. Use dedicated Secrets Manager instance for TFE
2. OR: Use secret groups with IAM policies at group level (requires manual policy creation)

---

## Secret Retrieval Process

### User Data Script Flow

```bash
#!/bin/bash
# templates/user_data.sh.tpl

# 1. Install IBM Cloud CLI
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh

# 2. Authenticate using instance identity token
IAM_TOKEN=$(curl -s -X POST "http://169.254.169.254/instance_identity/v1/token" \
  -H "Accept: application/json" | jq -r '.access_token')

# 3. Retrieve TFE license
TFE_LICENSE=$(ibmcloud secrets-manager secret \
  --instance-id ${secrets_manager_instance_id} \
  --secret-id ${tfe_license_secret_crn} \
  --iam-token $IAM_TOKEN \
  --output json | jq -r '.secret_data.payload')

# 4. Write to TFE configuration file
echo "$TFE_LICENSE" | base64 -d > /etc/tfe/license.hclic

# 5. Repeat for all other secrets...
```

**Error Handling**:
- If secret retrieval fails, VSI startup fails
- Load balancer health check detects unhealthy instance
- Instance group replaces failed instance automatically

---

## Secret Rotation Procedures

### TLS Certificate Rotation

```bash
# 1. Obtain new certificate (before expiration)
# 2. Update secret in Secrets Manager
ibmcloud secrets-manager secret-update \
  --secret-id ${tls_certificate_secret_crn} \
  --payload "$(cat new-certificate.pem)"

ibmcloud secrets-manager secret-update \
  --secret-id ${tls_private_key_secret_crn} \
  --payload "$(cat new-key.pem)"

# 3. Update load balancer (Terraform apply)
terraform apply -target=ibm_is_lb_listener.tfe_https

# 4. Verify new certificate
openssl s_client -connect tfe.example.com:443 -servername tfe.example.com
```

### Database Password Rotation

```bash
# 1. Generate new password
NEW_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | head -c 24)

# 2. Update secret in Secrets Manager
ibmcloud secrets-manager secret-update \
  --secret-id ${database_admin_password_secret_crn} \
  --payload "$NEW_PASSWORD"

# 3. Rotate database password
ibmcloud cdb user-password ${DATABASE_INSTANCE_ID} admin "$NEW_PASSWORD"

# 4. Rolling restart of TFE instances (active-active mode)
terraform apply -replace=ibm_is_instance_group.tfe

# 5. Verify TFE connectivity
curl -k https://tfe.example.com/_health_check
```

---

## Validation Checklist

Before running `terraform apply`, verify:

- [ ] All required secrets exist in Secrets Manager
- [ ] Secret CRNs are correct (copy/paste errors common)
- [ ] TLS certificate CN/SAN matches `tfe_hostname`
- [ ] TLS certificate and private key are matching pair
- [ ] TLS private key has no passphrase
- [ ] TLS certificate includes full chain (intermediate CAs)
- [ ] TFE license is not expired
- [ ] TFE license is base64-encoded
- [ ] Database password meets complexity requirements
- [ ] Redis password provided if `tfe_operational_mode = "active-active"`
- [ ] IAM authorization policy will be created by module (no manual action needed)

---

## Troubleshooting

### Common Issues

**Issue**: VSI fails to retrieve secrets  
**Symptoms**: Instance unhealthy, user data script errors in logs  
**Solution**: Verify IAM authorization policy exists, check secret CRN format

**Issue**: Load balancer fails to start with certificate error  
**Symptoms**: Terraform apply fails on `ibm_is_lb_listener` resource  
**Solution**: Verify certificate/key are matching pair, check for passphrase on key

**Issue**: TFE startup fails with license error  
**Symptoms**: TFE container exits immediately, license validation error in logs  
**Solution**: Verify license is valid `.hclic` file, check base64 encoding

**Issue**: TFE cannot connect to database  
**Symptoms**: Database connection errors in TFE logs  
**Solution**: Verify database password in Secrets Manager matches database admin password

---

## Summary

This contract defines:
- **6 required secrets** (always needed)
- **3 optional secrets** (conditional or legacy)
- **Secret format specifications** (JSON payloads, PEM format requirements)
- **Rotation procedures** for each secret type
- **Validation checklist** to verify before deployment

**Critical**: All secrets must be created in Secrets Manager BEFORE running `terraform apply`. Module will fail if secrets do not exist.
