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

# Keytab validation function
validate_keytab() {
    local keytab_file="$1"
    
    # Check if file exists and is not empty
    if [ ! -f "$keytab_file" ] || [ ! -s "$keytab_file" ]; then
        echo "ERROR: Keytab file is empty or does not exist" >&2
        return 1
    fi
    
    # Check file size (keytabs should be at least a few hundred bytes)
    local file_size=$(stat -c%s "$keytab_file" 2>/dev/null || stat -f%z "$keytab_file" 2>/dev/null)
    if [ "$file_size" -lt 100 ]; then
        echo "ERROR: Keytab file is too small (${file_size} bytes)" >&2
        return 1
    fi
    
    # Verify it's a valid keytab using klist
    if command -v klist &>/dev/null; then
        if ! klist -k -t "$keytab_file" &>/dev/null; then
            echo "ERROR: File is not a valid keytab (klist validation failed)" >&2
            return 1
        fi
        
        # Check if keytab has entries
        local entries=$(klist -k "$keytab_file" 2>/dev/null | grep -c "KVNO" || true)
        if [ "$entries" -eq 0 ]; then
            echo "ERROR: Keytab has no entries" >&2
            return 1
        fi
    else
        # Fallback: use file command if available
        if command -v file &>/dev/null; then
            local file_type=$(file -b "$keytab_file" 2>/dev/null || true)
            if [[ ! "$file_type" =~ "data" ]] && [[ ! "$file_type" =~ "Kerberos" ]]; then
                echo "WARNING: Cannot verify keytab format (klist not available)" >&2
            fi
        fi
    fi
    
    return 0
}

# Secure provisioning with validation
secure_provision() {
    local source_cmd="$1"
    local temp_file=$(mktemp -t keytab.XXXXXX)
    local exit_code=0
    
    # Ensure cleanup on exit
    trap "rm -f '$temp_file'" EXIT
    
    # Execute the source command and capture output
    if eval "$source_cmd" > "$temp_file" 2>/dev/null; then
        # Validate the keytab
        if validate_keytab "$temp_file"; then
            # Set secure permissions before moving
            chmod 600 "$temp_file"
            
            # Atomically move to destination
            mv -f "$temp_file" "$KEYTAB_DEST"
            chmod 600 "$KEYTAB_DEST"
            
            echo "Keytab validated and provisioned successfully"
            exit_code=0
        else
            echo "ERROR: Keytab validation failed" >&2
            rm -f "$temp_file"
            exit_code=1
        fi
    else
        echo "ERROR: Failed to retrieve keytab" >&2
        rm -f "$temp_file"
        exit_code=1
    fi
    
    # Remove trap
    trap - EXIT
    
    return $exit_code
}

# Method 1: HashiCorp Vault
provision_from_vault() {
    local vault_path="secret/data/ad/administrator-keytab"
    
    # Ensure vault is authenticated
    if ! vault token lookup &>/dev/null; then
        echo "ERROR: Not authenticated to Vault" >&2
        return 1
    fi
    
    # Retrieve and validate keytab from Vault (base64 encoded)
    local vault_cmd="vault kv get -field=keytab_base64 '$vault_path' | base64 -d"
    
    if ! secure_provision "$vault_cmd"; then
        echo "ERROR: Failed to provision keytab from Vault" >&2
        return 1
    fi
    
    return 0
}

# Method 2: AWS Secrets Manager
provision_from_aws_secrets() {
    local secret_name="hx/ad/administrator-keytab"
    local region="${AWS_REGION:-us-east-1}"
    
    # Retrieve and validate keytab from AWS Secrets Manager
    local aws_cmd="aws secretsmanager get-secret-value --secret-id '$secret_name' --region '$region' --query 'SecretBinary' --output text | base64 -d"
    
    if ! secure_provision "$aws_cmd"; then
        echo "ERROR: Failed to provision keytab from AWS Secrets Manager" >&2
        return 1
    fi
    
    return 0
}

# Method 3: Azure Key Vault
provision_from_azure_keyvault() {
    local vault_name="hx-keyvault"
    local secret_name="administrator-keytab"
    local temp_file=$(mktemp -t keytab.XXXXXX)
    
    # Ensure cleanup
    trap "rm -f '$temp_file'" EXIT
    
    # Retrieve keytab from Azure Key Vault to temp file
    if ! az keyvault secret download \
        --vault-name "$vault_name" \
        --name "$secret_name" \
        --file "$temp_file" &>/dev/null; then
        echo "ERROR: Failed to download keytab from Azure Key Vault" >&2
        rm -f "$temp_file"
        trap - EXIT
        return 1
    fi
    
    # Validate the keytab
    if validate_keytab "$temp_file"; then
        # Set secure permissions and move
        chmod 600 "$temp_file"
        mv -f "$temp_file" "$KEYTAB_DEST"
        chmod 600 "$KEYTAB_DEST"
        echo "Keytab validated and provisioned successfully"
        trap - EXIT
        return 0
    else
        echo "ERROR: Keytab validation failed" >&2
        rm -f "$temp_file"
        trap - EXIT
        return 1
    fi
}

# Method 4: Kubernetes Secret (for containerized environments)
provision_from_k8s_secret() {
    local namespace="hx-system"
    local secret_name="ad-administrator-keytab"
    
    # Retrieve and validate keytab from Kubernetes secret
    local k8s_cmd="kubectl get secret '$secret_name' -n '$namespace' -o jsonpath='{.data.keytab}' | base64 -d"
    
    if ! secure_provision "$k8s_cmd"; then
        echo "ERROR: Failed to provision keytab from Kubernetes secret" >&2
        return 1
    fi
    
    return 0
}

# Main provisioning logic
main() {
    local result=0
    
    # Detect which secrets manager to use based on environment
    if [ -n "${VAULT_ADDR:-}" ]; then
        echo "Provisioning keytab from HashiCorp Vault..."
        if provision_from_vault; then
            result=0
        else
            result=1
        fi
    elif [ -n "${AWS_REGION:-}" ] && command -v aws &>/dev/null; then
        echo "Provisioning keytab from AWS Secrets Manager..."
        if provision_from_aws_secrets; then
            result=0
        else
            result=1
        fi
    elif command -v az &>/dev/null && az account show &>/dev/null; then
        echo "Provisioning keytab from Azure Key Vault..."
        if provision_from_azure_keyvault; then
            result=0
        else
            result=1
        fi
    elif command -v kubectl &>/dev/null && kubectl auth can-i get secrets &>/dev/null; then
        echo "Provisioning keytab from Kubernetes..."
        if provision_from_k8s_secret; then
            result=0
        else
            result=1
        fi
    else
        echo "ERROR: No secrets manager detected. Please configure one of:"
        echo "  - HashiCorp Vault (set VAULT_ADDR)"
        echo "  - AWS Secrets Manager (configure AWS CLI)"
        echo "  - Azure Key Vault (login with 'az login')"
        echo "  - Kubernetes (configure kubectl)"
        exit 1
    fi
    
    if [ $result -eq 0 ]; then
        echo "Keytab provisioned successfully at: $KEYTAB_DEST"
        echo "Remember to delete this file after use!"
    else
        echo "ERROR: Failed to provision keytab" >&2
        exit 1
    fi
    
    return $result
}

# Run main function
main "$@"