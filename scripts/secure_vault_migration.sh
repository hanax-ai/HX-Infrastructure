#!/bin/bash
#
# Ansible Vault Security Migration Script
# This script helps migrate from file-based vault passwords to secure alternatives
#

set -euo pipefail

echo "=== Ansible Vault Security Migration ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check current status
echo -e "${YELLOW}Current Security Status:${NC}"
echo

# Check if vault password file exists
if [ -f ".vault_pass.txt" ]; then
    echo -e "${RED}✗ Found .vault_pass.txt in current directory${NC}"
    PERMS=$(stat -c %a .vault_pass.txt 2>/dev/null || stat -f %Lp .vault_pass.txt 2>/dev/null || echo "unknown")
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
        echo -e "${GREEN}✓ File has restrictive permissions: $PERMS${NC}"
    else
        echo -e "${RED}✗ File has insecure permissions: $PERMS${NC}"
    fi
else
    echo -e "${GREEN}✓ No .vault_pass.txt found in current directory${NC}"
fi

# Check gitignore
if grep -q "\.vault_pass\.txt" .gitignore 2>/dev/null; then
    echo -e "${GREEN}✓ .vault_pass.txt is in .gitignore${NC}"
else
    echo -e "${RED}✗ .vault_pass.txt is NOT in .gitignore${NC}"
fi

# Check ansible.cfg
if grep -q "vault_password_file" ansible.cfg 2>/dev/null; then
    echo -e "${YELLOW}⚠ ansible.cfg contains vault_password_file setting${NC}"
else
    echo -e "${GREEN}✓ ansible.cfg does not contain vault_password_file${NC}"
fi

echo
echo -e "${YELLOW}Migration Options:${NC}"
echo "1. Use environment variable (recommended for CI/CD)"
echo "2. Use --ask-vault-pass flag (recommended for interactive use)"
echo "3. Use external secret management (recommended for production)"
echo

read -p "Select option (1-3): " OPTION

case $OPTION in
    1)
        echo
        echo -e "${GREEN}Environment Variable Setup:${NC}"
        echo
        echo "Add to your deployment pipeline or shell profile:"
        echo
        echo "export ANSIBLE_VAULT_PASSWORD_FILE=/dev/stdin"
        echo "export ANSIBLE_VAULT_PASSWORD='your-secure-password'"
        echo
        echo "Then run playbooks with:"
        echo 'echo "$ANSIBLE_VAULT_PASSWORD" | ansible-playbook site.yml'
        echo
        
        read -p "Remove vault_password_file from ansible.cfg? (y/n): " REMOVE_CONFIG
        if [ "$REMOVE_CONFIG" = "y" ]; then
            sed -i.bak '/vault_password_file/d' ansible.cfg
            echo -e "${GREEN}✓ Removed vault_password_file from ansible.cfg${NC}"
            echo "  Backup saved as ansible.cfg.bak"
        fi
        ;;
        
    2)
        echo
        echo -e "${GREEN}Interactive Password Setup:${NC}"
        echo
        echo "This will remove vault_password_file from ansible.cfg"
        echo "You'll need to use --ask-vault-pass with all playbook runs"
        echo
        
        read -p "Proceed? (y/n): " PROCEED
        if [ "$PROCEED" = "y" ]; then
            sed -i.bak '/vault_password_file/d' ansible.cfg
            echo -e "${GREEN}✓ Removed vault_password_file from ansible.cfg${NC}"
            echo "  Backup saved as ansible.cfg.bak"
            echo
            echo "Now run playbooks with:"
            echo "ansible-playbook site.yml --ask-vault-pass"
        fi
        ;;
        
    3)
        echo
        echo -e "${GREEN}External Secret Management:${NC}"
        echo
        echo "Examples for common providers:"
        echo
        echo "HashiCorp Vault:"
        echo 'export ANSIBLE_VAULT_PASSWORD=$(vault kv get -field=password secret/ansible/vault)'
        echo
        echo "AWS Secrets Manager:"
        echo 'export ANSIBLE_VAULT_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ansible-vault --query SecretString --output text)'
        echo
        echo "Azure Key Vault:"
        echo 'export ANSIBLE_VAULT_PASSWORD=$(az keyvault secret show --vault-name MyVault --name ansible-vault --query value -o tsv)'
        echo
        ;;
        
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo
echo -e "${YELLOW}Security Recommendations:${NC}"
echo "1. Delete any local vault password files after migration"
echo "2. Rotate vault passwords after implementing new method"
echo "3. Use different passwords for different environments"
echo "4. Audit vault file access regularly"
echo

read -p "Delete .vault_pass.txt if it exists? (y/n): " DELETE_FILE
if [ "$DELETE_FILE" = "y" ] && [ -f ".vault_pass.txt" ]; then
    rm -f .vault_pass.txt
    echo -e "${GREEN}✓ Deleted .vault_pass.txt${NC}"
fi

echo
echo -e "${GREEN}Migration complete!${NC}"
echo
echo "Next steps:"
echo "1. Test your new authentication method"
echo "2. Update your deployment documentation"
echo "3. Rotate vault passwords using: ansible-vault rekey <vault-file>"