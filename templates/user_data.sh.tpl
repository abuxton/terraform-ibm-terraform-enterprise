#!/bin/bash
# Copyright 2024 IBM Corp.
# TFE Bootstrap Script - User Data for IBM Cloud VSI
# This script runs on first boot to install and configure Terraform Enterprise

set -e
set -o pipefail

##############################################################################
# Variables (injected by Terraform templatefile() function)
##############################################################################

export TFE_HOSTNAME="${tfe_hostname}"
export TFE_OPERATIONAL_MODE="${tfe_operational_mode}"
export TFE_IMAGE="${tfe_image}"
export TFE_LICENSE_SECRET_CRN="${tfe_license_secret_crn}"
export TFE_ENCRYPTION_PASSWORD_SECRET_CRN="${tfe_encryption_password_secret_crn}"
export DATABASE_HOST="${database_host}"
export DATABASE_PORT="${database_port}"
export DATABASE_NAME="${database_name}"
export DATABASE_PASSWORD_SECRET_CRN="${database_password_secret_crn}"
export COS_BUCKET_NAME="${cos_bucket_name}"
export COS_REGION="${cos_region}"
export SECRETS_MANAGER_REGION="${secrets_manager_region}"
%{ if is_active_active ~}
export TFE_REDIS_HOST="${redis_host}"
export TFE_REDIS_PORT="${redis_port}"
export TFE_REDIS_PASSWORD_SECRET_CRN="${redis_password_secret_crn}"
%{ endif ~}

##############################################################################
# Logging Setup
##############################################################################

LOG_FILE="/var/log/tfe-bootstrap.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "TFE Bootstrap Started: $(date)"
echo "=========================================="

##############################################################################
# System Updates and Dependencies
##############################################################################

echo "[$(date)] Installing system dependencies..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
else
    echo "ERROR: Cannot detect OS version"
    exit 1
fi

# Install Docker/Podman based on OS
if [[ "$OS" == "ubuntu" ]]; then
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        jq \
        unzip

    # Install Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

elif [[ "$OS" =~ ^(rhel|rocky)$ ]]; then
    yum update -y
    yum install -y \
        ca-certificates \
        curl \
        jq \
        unzip

    # Install Docker or Podman
    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    systemctl enable docker
    systemctl start docker
else
    echo "ERROR: Unsupported OS: $OS"
    exit 1
fi

##############################################################################
# Install IBM Cloud CLI (for Secrets Manager access)
##############################################################################

echo "[$(date)] Installing IBM Cloud CLI..."
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh

# Install Secrets Manager plugin
ibmcloud plugin install secrets-manager -f

# Authenticate using instance identity (IAM metadata service)
ibmcloud login --apikey "$(curl -s -X POST 'http://169.254.169.254/instance_identity/v1/token?version=2022-03-01' -H 'Metadata-Flavor: ibm' -H 'Accept: application/json' | jq -r .access_token)"

##############################################################################
# Retrieve Secrets from Secrets Manager
##############################################################################

echo "[$(date)] Retrieving secrets from Secrets Manager..."

# Function to retrieve secret value
get_secret() {
    local secret_crn=$1
    local secret_id=$(echo "$secret_crn" | awk -F':secret:' '{print $2}')
    local secrets_manager_instance=$(echo "$secret_crn" | awk -F':' '{print $(NF-1)}')
    
    ibmcloud secrets-manager secret --secret-id "$secret_id" --instance-id "$secrets_manager_instance" --output json | jq -r '.resources[0].secret_data'
}

TFE_LICENSE=$(get_secret "$TFE_LICENSE_SECRET_CRN")
TFE_ENCRYPTION_PASSWORD=$(get_secret "$TFE_ENCRYPTION_PASSWORD_SECRET_CRN")
DATABASE_PASSWORD=$(get_secret "$DATABASE_PASSWORD_SECRET_CRN")
%{ if is_active_active ~}
TFE_REDIS_PASSWORD=$(get_secret "$TFE_REDIS_PASSWORD_SECRET_CRN")
%{ endif ~}

##############################################################################
# Configure TFE Environment
##############################################################################

echo "[$(date)] Configuring TFE environment..."

# Create TFE configuration directory
mkdir -p /etc/tfe
mkdir -p /var/lib/tfe

# Write TFE configuration
cat > /etc/tfe/settings.env << EOFSETTINGS
TFE_HOSTNAME=$TFE_HOSTNAME
TFE_OPERATIONAL_MODE=$TFE_OPERATIONAL_MODE
TFE_LICENSE=$TFE_LICENSE
TFE_ENCRYPTION_PASSWORD=$TFE_ENCRYPTION_PASSWORD

# Database Configuration
TFE_DATABASE_HOST=$DATABASE_HOST
TFE_DATABASE_PORT=$DATABASE_PORT
TFE_DATABASE_NAME=$DATABASE_NAME
TFE_DATABASE_USER=admin
TFE_DATABASE_PASSWORD=$DATABASE_PASSWORD

# Object Storage Configuration
TFE_OBJECT_STORAGE_TYPE=s3
TFE_OBJECT_STORAGE_S3_BUCKET=$COS_BUCKET_NAME
TFE_OBJECT_STORAGE_S3_REGION=$COS_REGION
TFE_OBJECT_STORAGE_S3_USE_INSTANCE_PROFILE=true

%{ if is_active_active ~}
# Redis Configuration (Active-Active Mode)
TFE_REDIS_HOST=$TFE_REDIS_HOST
TFE_REDIS_PORT=$TFE_REDIS_PORT
TFE_REDIS_PASSWORD=$TFE_REDIS_PASSWORD
TFE_REDIS_USE_AUTH=true
TFE_REDIS_USE_TLS=true
%{ endif ~}

# TLS Configuration
TFE_TLS_CERT_FILE=/etc/tfe/cert.pem
TFE_TLS_KEY_FILE=/etc/tfe/key.pem
TFE_TLS_CA_BUNDLE_FILE=/etc/tfe/ca-bundle.pem

# Logging
TFE_LOG_FORWARDING_ENABLED=false
EOFSETTINGS

chmod 600 /etc/tfe/settings.env

##############################################################################
# Start TFE Container
##############################################################################

echo "[$(date)] Starting TFE container..."

docker run -d \
    --name tfe \
    --restart unless-stopped \
    -p 443:443 \
    -p 8080:8080 \
    --env-file /etc/tfe/settings.env \
    -v /var/lib/tfe:/var/lib/tfe \
    $TFE_IMAGE

##############################################################################
# Health Check
##############################################################################

echo "[$(date)] Waiting for TFE to become healthy..."

MAX_WAIT=600  # 10 minutes
ELAPSED=0
HEALTH_CHECK_URL="http://localhost:8080/_health_check"

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -sf "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        echo "[$(date)] TFE is healthy!"
        break
    fi
    echo "[$(date)] Waiting for TFE health check... ($ELAPSED seconds elapsed)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "ERROR: TFE did not become healthy within $MAX_WAIT seconds"
    docker logs tfe
    exit 1
fi

##############################################################################
# Bootstrap Complete
##############################################################################

echo "=========================================="
echo "TFE Bootstrap Completed: $(date)"
echo "TFE URL: https://$TFE_HOSTNAME"
echo "=========================================="
