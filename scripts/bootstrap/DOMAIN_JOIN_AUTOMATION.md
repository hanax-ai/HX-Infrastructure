# Secure Domain Join Automation Guide

## Overview
This guide documents the secure, non-interactive domain join process for HX infrastructure hosts.

## Security Improvements

### Previous Issues
- Interactive password prompts blocked automation
- Potential for password exposure in command history
- No error handling for failed authentication
- Manual intervention required

### New Approach
- Kerberos keytab-based authentication (non-interactive)
- Secrets manager integration for keytab provisioning
- Proper file permissions (600) enforcement
- Automatic cleanup of sensitive files
- Comprehensive error handling

## Prerequisites

1. **Keytab Generation** (run on domain controller):
   ```bash
   ktutil
   addent -password -p administrator@DEV-TEST.HANA-X.AI -k 1 -e aes256-cts-hmac-sha1-96
   # Enter password when prompted
   wkt administrator.keytab
   quit
   ```

2. **Store Keytab in Secrets Manager**:
   ```bash
   # HashiCorp Vault example
   base64 administrator.keytab | vault kv put secret/ad/administrator-keytab keytab_base64=-
   
   # AWS Secrets Manager example
   aws secretsmanager create-secret \
     --name hx/ad/administrator-keytab \
     --secret-binary fileb://administrator.keytab
   ```

## Usage

### Method 1: Using the Bootstrap Script
```bash
# Provision keytab first
./scripts/bootstrap/provision-keytab.sh /tmp/administrator.keytab

# Run domain join
HX_IP=192.168.10.5 \
HX_KEYTAB_SOURCE=/tmp/administrator.keytab \
./scripts/bootstrap/hx-join.sh
```

### Method 2: Using Ansible Playbook
```bash
# With keytab from Vault (requires vault authentication)
ansible-playbook playbooks/domain_join_automated.yml \
  -i inventories/dev.ini \
  -l new-host

# With local keytab file
ansible-playbook playbooks/domain_join_automated.yml \
  -i inventories/dev.ini \
  -l new-host \
  -e keytab_source=/secure/path/to/administrator.keytab
```

### Method 3: CI/CD Pipeline
```yaml
# GitLab CI example
domain_join:
  stage: configure
  script:
    # Authenticate to Vault
    - export VAULT_TOKEN=$(vault login -token-only -method=jwt role=ci-role)
    
    # Provision keytab
    - ./scripts/bootstrap/provision-keytab.sh /tmp/admin.keytab
    
    # Run domain join
    - |
      HX_IP=${TARGET_IP} \
      HX_KEYTAB_SOURCE=/tmp/admin.keytab \
      ./scripts/bootstrap/hx-join.sh
    
    # Cleanup
    - rm -f /tmp/admin.keytab
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HX_KEYTAB_SOURCE` | Path to administrator keytab | `/tmp/administrator.keytab` |
| `HX_IP` | Host IP address | Required |
| `HX_FQDN` | Fully qualified domain name | Auto-detected |
| `HX_GW` | Gateway IP | `192.168.10.1` |
| `HX_DC` | Domain controller IP | `192.168.10.2` |
| `HX_REALM` | Kerberos realm | `DEV-TEST.HANA-X.AI` |
| `HX_DOMAIN` | DNS domain | `dev-test.hana-x.ai` |
| `HX_PERMIT_GROUPS` | AD groups to permit | `Domain Admins,DevOps Users` |

## Security Best Practices

1. **Keytab Management**:
   - Never commit keytabs to version control
   - Store in encrypted secrets manager
   - Rotate keytabs regularly (monthly)
   - Use service accounts instead of administrator when possible

2. **File Permissions**:
   - Keytabs must have 600 permissions
   - Owned by root or service user
   - Delete immediately after use

3. **Automation Security**:
   - Use secure credential injection (no command line passwords)
   - Implement proper error handling
   - Log authentication attempts
   - Monitor for unauthorized domain joins

4. **Network Security**:
   - Ensure secure communication with DC
   - Use internal DNS servers only
   - Implement firewall rules for AD ports

## Troubleshooting

### Common Issues

1. **Keytab Authentication Fails**:
   ```bash
   # Verify keytab
   klist -kt /path/to/keytab
   
   # Test authentication
   kinit -kt /path/to/keytab administrator@DEV-TEST.HANA-X.AI
   ```

2. **Realm Join Fails**:
   ```bash
   # Check realm discovery
   realm discover DEV-TEST.HANA-X.AI
   
   # Verify DNS resolution
   nslookup _ldap._tcp.dev-test.hana-x.ai
   ```

3. **SSSD Issues**:
   ```bash
   # Check SSSD status
   systemctl status sssd
   
   # Clear SSSD cache
   sss_cache -E
   
   # Test user lookup
   id administrator@dev-test.hana-x.ai
   ```

## Monitoring

Add these checks to your monitoring system:

1. Domain membership status: `realm list`
2. Kerberos ticket validity: `klist -s`
3. SSSD service health: `systemctl is-active sssd`
4. User lookup functionality: `id administrator@dev-test.hana-x.ai`

## Migration from Interactive Script

To migrate existing systems:

1. Generate and store keytab in secrets manager
2. Update automation scripts to use new non-interactive version
3. Test in non-production environment
4. Deploy with proper error handling
5. Monitor for issues during rollout