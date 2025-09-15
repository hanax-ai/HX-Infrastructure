# Ansible Vault Security Best Practices

## Current Security Status

✅ **Already Implemented:**
- `.vault_pass.txt` is listed in `.gitignore`
- File has restrictive permissions (600)
- No vault password files found in git history

## Production Security Recommendations

### 1. Remove File-Based Vault Password

For production environments, **DO NOT** use file-based vault passwords. Instead, use one of these approaches:

#### Option A: Environment Variable
```bash
# Set in your deployment pipeline or shell profile
export ANSIBLE_VAULT_PASSWORD_FILE=/dev/stdin
export ANSIBLE_VAULT_PASSWORD="your-secure-password"

# Use with ansible-playbook
echo "$ANSIBLE_VAULT_PASSWORD" | ansible-playbook site.yml
```

#### Option B: Prompt for Password
```bash
# Remove vault_password_file from ansible.cfg
# Use --ask-vault-pass flag
ansible-playbook site.yml --ask-vault-pass
```

#### Option C: External Secret Management
```bash
# Use HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, etc.
# Example with HashiCorp Vault:
export ANSIBLE_VAULT_PASSWORD=$(vault kv get -field=password secret/ansible/vault)
echo "$ANSIBLE_VAULT_PASSWORD" | ansible-playbook site.yml
```

### 2. Update ansible.cfg for Production

Remove the `vault_password_file` line from ansible.cfg:

```ini
[defaults]
# vault_password_file = .vault_pass.txt  # REMOVED for security
```

### 3. Rotate Vault Password

After implementing secure password management:

```bash
# 1. Re-encrypt all vault files with new password
ansible-vault rekey inventories/group_vars/all/vault.yml
ansible-vault rekey inventories/group_vars/all/webui_api_token.yml

# 2. Update password in your secure backend
# 3. Delete any local password files
rm -f .vault_pass.txt ~/.vault_pass
```

### 4. CI/CD Pipeline Integration

Example GitLab CI configuration:
```yaml
deploy:
  script:
    - echo "$ANSIBLE_VAULT_PASSWORD" | ansible-playbook site.yml
  variables:
    ANSIBLE_VAULT_PASSWORD_FILE: /dev/stdin
```

Example GitHub Actions:
```yaml
- name: Run Ansible Playbook
  env:
    ANSIBLE_VAULT_PASSWORD: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
  run: |
    echo "$ANSIBLE_VAULT_PASSWORD" | ansible-playbook site.yml
```

## Security Checklist

- [ ] Remove `vault_password_file` from ansible.cfg for production
- [ ] Never commit vault password files to git
- [ ] Use environment variables or external secret management
- [ ] Rotate vault passwords regularly
- [ ] Audit vault file access logs
- [ ] Use different vault passwords for different environments
- [ ] Implement least-privilege access to vault passwords

## Emergency Response

If a vault password is exposed:

1. **Immediately rotate the password**:
   ```bash
   ansible-vault rekey --ask-vault-pass inventories/group_vars/all/*.yml
   ```

2. **Audit encrypted files** for sensitive data exposure

3. **Update all systems** that use the compromised password

4. **Review access logs** for unauthorized access

5. **Notify security team** of the incident