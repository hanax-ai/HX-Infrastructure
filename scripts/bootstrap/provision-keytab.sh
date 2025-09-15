#!/usr/bin/env bash
# Keytab Provisioning Script - Example for retrieving administrator keytab
#
# This script demonstrates secure keytab provisioning from various secrets managers.
# Choose the appropriate method for your environment.
#
# Security Best Practices:
#   - Never store keytabs in version control
#   - Always use proper file permissions (600)
#   - Delete keytabs after use
#   - Rotate keytabs regularly
#   - Use service accounts instead of administrator when possible

set -euo pipefail

KEYTAB_DEST="${1:-/tmp/administrator.keytab}"

# Method 1: HashiCorp Vault
provision_from_vault() {
    local vault_path="secret/data/ad/administrator-keytab"
    
    # Ensure vault is authenticated
    if ! vault token lookup &>/dev/null; then
        echo "ERROR: Not authenticated to Vault" >&2
        exit 1
    fi
    
    # Retrieve keytab from Vault (base64 encoded)
    vault kv get -field=keytab_base64 "$vault_path" | base64 -d > "$KEYTAB_DEST"
    chmod 600 "$KEYTAB_DEST"
}

# Method 2: AWS Secrets Manager
provision_from_aws_secrets() {
    local secret_name="hx/ad/administrator-keytab"
    local region="${AWS_REGION:-us-east-1}"
    
    # Retrieve keytab from AWS Secrets Manager
    aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --region "$region" \
        --query 'SecretBinary' \
        --output text | base64 -d > "$KEYTAB_DEST"
    chmod 600 "$KEYTAB_DEST"
}

# Method 3: Azure Key Vault
provision_from_azure_keyvault() {
    local vault_name="hx-keyvault"
    local secret_name="administrator-keytab"
    
    # Retrieve keytab from Azure Key Vault
    az keyvault secret download \
        --vault-name "$vault_name" \
        --name "$secret_name" \
        --file "$KEYTAB_DEST"
    chmod 600 "$KEYTAB_DEST"
}

# Method 4: Kubernetes Secret (for containerized environments)
provision_from_k8s_secret() {
    local namespace="hx-system"
    local secret_name="ad-administrator-keytab"
    
    # Retrieve keytab from Kubernetes secret
    kubectl get secret "$secret_name" \
        -n "$namespace" \
        -o jsonpath='{.data.keytab}' | base64 -d > "$KEYTAB_DEST"
    chmod 600 "$KEYTAB_DEST"
}

# Main provisioning logic
main() {
    # Detect which secrets manager to use based on environment
    if [ -n "${VAULT_ADDR:-}" ]; then
        echo "Provisioning keytab from HashiCorp Vault..."
        provision_from_vault
    elif [ -n "${AWS_REGION:-}" ] && command -v aws &>/dev/null; then
        echo "Provisioning keytab from AWS Secrets Manager..."
        provision_from_aws_secrets
    elif command -v az &>/dev/null && az account show &>/dev/null; then
        echo "Provisioning keytab from Azure Key Vault..."
        provision_from_azure_keyvault
    elif command -v kubectl &>/dev/null && kubectl auth can-i get secrets &>/dev/null; then
        echo "Provisioning keytab from Kubernetes..."
        provision_from_k8s_secret
    else
        echo "ERROR: No secrets manager detected. Please configure one of:"
        echo "  - HashiCorp Vault (set VAULT_ADDR)"
        echo "  - AWS Secrets Manager (configure AWS CLI)"
        echo "  - Azure Key Vault (login with 'az login')"
        echo "  - Kubernetes (configure kubectl)"
        exit 1
    fi
    
    echo "Keytab provisioned successfully at: $KEYTAB_DEST"
    echo "Remember to delete this file after use!"
}

# Run main function
main "$@"