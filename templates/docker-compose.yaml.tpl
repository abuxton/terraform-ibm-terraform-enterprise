# Copyright 2024 IBM Corp.
# TFE Docker Compose Configuration
# This file is templated by Terraform and placed on the VSI

version: '3.8'

services:
  tfe:
    image: ${tfe_image}
    container_name: tfe
    restart: unless-stopped
    
    ports:
      - "443:443"
      - "8080:8080"
      %{ if enable_metrics ~}
      - "9090:9090"
      - "9091:9091"
      %{ endif ~}
    
    environment:
      # TFE Core Configuration
      TFE_HOSTNAME: "${tfe_hostname}"
      TFE_OPERATIONAL_MODE: "${tfe_operational_mode}"
      TFE_LICENSE: "${tfe_license}"
      TFE_ENCRYPTION_PASSWORD: "${tfe_encryption_password}"
      
      # Database Configuration
      TFE_DATABASE_HOST: "${database_host}"
      TFE_DATABASE_PORT: "${database_port}"
      TFE_DATABASE_NAME: "${database_name}"
      TFE_DATABASE_USER: "admin"
      TFE_DATABASE_PASSWORD: "${database_password}"
      TFE_DATABASE_PARAMETERS: "sslmode=require"
      
      # Object Storage Configuration
      TFE_OBJECT_STORAGE_TYPE: "s3"
      TFE_OBJECT_STORAGE_S3_BUCKET: "${cos_bucket_name}"
      TFE_OBJECT_STORAGE_S3_REGION: "${cos_region}"
      TFE_OBJECT_STORAGE_S3_ENDPOINT: "https://s3.${cos_region}.cloud-object-storage.appdomain.cloud"
      TFE_OBJECT_STORAGE_S3_USE_INSTANCE_PROFILE: "true"
      
      %{ if is_active_active ~}
      # Redis Configuration (Active-Active Mode)
      TFE_REDIS_HOST: "${redis_host}"
      TFE_REDIS_PORT: "${redis_port}"
      TFE_REDIS_PASSWORD: "${redis_password}"
      TFE_REDIS_USE_AUTH: "true"
      TFE_REDIS_USE_TLS: "true"
      %{ endif ~}
      
      # TLS Configuration
      TFE_TLS_CERT_FILE: "/etc/tfe/cert.pem"
      TFE_TLS_KEY_FILE: "/etc/tfe/key.pem"
      TFE_TLS_CA_BUNDLE_FILE: "/etc/tfe/ca-bundle.pem"
      TFE_TLS_ENFORCE: "true"
      TFE_TLS_VERSION: "tls_1_2_tls_1_3"
      
      # HTTP Proxy Configuration (if configured)
      %{ if http_proxy != "" ~}
      HTTP_PROXY: "${http_proxy}"
      HTTPS_PROXY: "${https_proxy}"
      NO_PROXY: "${no_proxy}"
      %{ endif ~}
      
      # Logging Configuration
      TFE_LOG_FORWARDING_ENABLED: "${log_forwarding_enabled}"
      %{ if log_forwarding_enabled ~}
      TFE_LOG_FORWARDING_CONFIG_PATH: "/etc/tfe/fluent-bit.conf"
      %{ endif ~}
      
      # Metrics Configuration
      %{ if enable_metrics ~}
      TFE_METRICS_ENABLE: "true"
      TFE_METRICS_HTTP_PORT: "9090"
      TFE_METRICS_HTTPS_PORT: "9091"
      %{ endif ~}
    
    volumes:
      - /var/lib/tfe:/var/lib/tfe
      - /etc/tfe:/etc/tfe:ro
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/_health_check"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5m
    
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
