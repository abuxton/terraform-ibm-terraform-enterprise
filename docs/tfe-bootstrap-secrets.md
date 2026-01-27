# TFE Secrets Bootstrap Guide

This guide explains how to prepare all required secrets in IBM Cloud Secrets Manager before deploying the TFE module.

## Overview

The TFE module requires all secrets to be pre-created in Secrets Manager. This approach:
- Avoids circular dependencies (module doesn't create secrets)
- Enables proper secret lifecycle management
- Ensures secrets are never stored in Terraform state
- Follows HashiCorp Validated Design pattern

## Required Secrets

The following secrets must be created in your Secrets Manager instance:

### 1. TFE License File

**Type**: Arbitrary secret  
**Name**: `tfe-license`  
**Content**: Your TFE license file (`.rli` file contents)

```bash
# Upload license file
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name tfe-license \
  --secret-data "$(cat terraform-enterprise.rli)"
```

### 2. TFE Encryption Password

**Type**: Arbitrary secret  
**Name**: `tfe-encryption-password`  
**Content**: Strong password (32+ characters) for TFE internal encryption

```bash
# Generate and store encryption password
export TFE_ENC_PASSWORD=$(openssl rand -base64 32)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name tfe-encryption-password \
  --secret-data "$TFE_ENC_PASSWORD"
```

### 3. Database Admin Password

**Type**: Arbitrary secret  
**Name**: `tfe-database-password`  
**Content**: PostgreSQL admin password (16+ characters, alphanumeric + special chars)

```bash
# Generate and store database password
export DB_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name tfe-database-password \
  --secret-data "$DB_PASSWORD"
```

### 4. TLS Certificate (for HTTPS)

**Type**: Imported certificate  
**Name**: `tfe-tls-certificate`  
**Content**: X.509 certificate matching your TFE hostname + private key

```bash
# Import TLS certificate
ibmcloud secrets-manager secret-create \
  --secret-type imported_cert \
  --name tfe-tls-certificate \
  --certificate "$(cat tfe.example.com.crt)" \
  --private-key "$(cat tfe.example.com.key)"
```

**Important**: The certificate must match your `tfe_hostname` variable. For example:
- If `tfe_hostname = "tfe.example.com"`, certificate CN or SAN must include `tfe.example.com`
- Use wildcard certificate (`*.example.com`) if deploying multiple TFE instances

### 5. Redis Password (Active-Active Mode Only)

**Type**: Arbitrary secret  
**Name**: `tfe-redis-password`  
**Content**: Redis authentication password (16+ characters)

```bash
# Generate and store Redis password (only for active-active mode)
export REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
ibmcloud secrets-manager secret-create \
  --secret-type arbitrary \
  --name tfe-redis-password \
  --secret-data "$REDIS_PASSWORD"
```

## Retrieving Secret CRNs

After creating secrets, retrieve their CRNs for use in Terraform variables:

```bash
# List all secrets in your Secrets Manager instance
ibmcloud secrets-manager secrets --instance-id <SECRETS_MANAGER_INSTANCE_ID>

# Get specific secret details
ibmcloud secrets-manager secret --secret-id <SECRET_ID> --instance-id <INSTANCE_ID>
```

The CRN format is:
```
crn:v1:bluemix:public:secrets-manager:<region>:a/<account-id>:<instance-id>:secret:<secret-id>
```

## Terraform Variable Mapping

Use the retrieved CRNs in your Terraform configuration:

```hcl
# Secrets Manager instance
secrets_manager_instance_crn = "crn:v1:bluemix:public:secrets-manager:us-south:a/..."

# Individual secret CRNs
tfe_license_secret_crn             = "crn:v1:bluemix:public:secrets-manager:us-south:a/.../secret/abc123"
tfe_encryption_password_secret_crn = "crn:v1:bluemix:public:secrets-manager:us-south:a/.../secret/def456"
database_password_secret_crn       = "crn:v1:bluemix:public:secrets-manager:us-south:a/.../secret/ghi789"
tls_certificate_crn                = "crn:v1:bluemix:public:secrets-manager:us-south:a/.../secret/jkl012"

# For active-active mode
redis_password_secret_crn = "crn:v1:bluemix:public:secrets-manager:us-south:a/.../secret/mno345"
```

## Security Best Practices

1. **Least Privilege**: Grant VSI instances only `SecretsReader` role, not `SecretsWriter`
2. **Secret Rotation**: Rotate passwords every 90 days (see [tfe-cert-rotation.md](tfe-cert-rotation.md))
3. **Audit Logging**: Enable Activity Tracker to log secret access events
4. **Backup**: Export secret metadata (not values) for disaster recovery planning
5. **Access Control**: Limit Secrets Manager access to authorized personnel only

## Validation

Before deploying TFE, validate all secrets are accessible:

```bash
# Test secret retrieval
for secret_id in <tfe-license-id> <tfe-enc-password-id> <db-password-id> <tls-cert-id>; do
  echo "Testing secret: $secret_id"
  ibmcloud secrets-manager secret --secret-id $secret_id --instance-id <INSTANCE_ID> > /dev/null
  if [ $? -eq 0 ]; then
    echo "✓ Secret accessible"
  else
    echo "✗ Secret not accessible"
  fi
done
```

## Troubleshooting

### Error: "Secret not found"
- Verify secret exists: `ibmcloud secrets-manager secrets`
- Check secret ID matches CRN in Terraform variables
- Ensure Secrets Manager instance ID is correct

### Error: "Unauthorized"
- Verify IAM authorization policy exists (VSI → Secrets Manager)
- Check VSI service ID has `SecretsReader` role
- Confirm secret is in same account as VSI

### Error: "Invalid certificate"
- Verify certificate CN/SAN matches `tfe_hostname`
- Check certificate is not expired: `openssl x509 -in cert.pem -noout -dates`
- Ensure private key matches certificate

## Next Steps

After secrets are prepared:
1. Proceed with [basic deployment example](../examples/basic/)
2. Review [deployment customizations guide](deployment-customizations.md)
3. Plan for [certificate rotation](tfe-cert-rotation.md)
