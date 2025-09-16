# LiteLLM Security Best Practices Guide

## Overview

This document outlines critical security practices for the LiteLLM API Gateway deployment. Following these guidelines is **mandatory** for production environments.

## 🔴 Critical Security Issues

### 1. Master Key Exposure

**Current Issue**: The master key is being used directly in client applications (Open WebUI).

**Risk Level**: **CRITICAL**

**Why It's Wrong**:
- Master key has unlimited privileges
- Can create/delete other keys
- Full access to all models and settings
- Compromise affects entire system

**Correct Approach**:
```bash
# 1. Use master key ONLY to generate virtual keys
curl -X POST http://api-gateway:4000/key/generate \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{"key_alias": "client-app", "duration": "90d"}'

# 2. Use the generated virtual key in client apps
export OPENAI_API_KEY="sk-generated-virtual-key"
```

### 2. Database Configuration Missing

**Current Issue**: LiteLLM deployed without database, preventing virtual key management.

**Risk Level**: **HIGH**

**Solution**:
1. Deploy PostgreSQL database
2. Configure LiteLLM with database URL
3. Enable virtual key generation
4. Implement key lifecycle management

## ✅ Security Best Practices

### 1. Key Management Hierarchy

```
Master Key (Root)
    ├── Admin Keys (for key management)
    ├── Service Keys (for applications)
    │   ├── open-webui-key
    │   ├── monitoring-key
    │   └── backup-service-key
    └── User Keys (for individual users)
```

### 2. Key Rotation Policy

**Master Key**: Rotate every 90 days
```bash
# Generate new master key
openssl rand -hex 32 | sed 's/^/sk-/'

# Update in Ansible vault
ansible-vault encrypt_string --name litellm_master_key "sk-new-key-here"

# Deploy with zero downtime
ansible-playbook litellm_key_rotation.yml
```

**Virtual Keys**: Rotate based on usage
- Production apps: 90 days
- Development: 30 days
- Testing: 7 days

### 3. Access Control

#### Network Level
```yaml
# iptables rules for API gateway
-A INPUT -p tcp --dport 4000 -s 192.168.10.0/24 -j ACCEPT
-A INPUT -p tcp --dport 4000 -j DROP
```

#### Application Level
```yaml
# LiteLLM config with restrictions
general_settings:
  master_key: "{{ vault_litellm_master_key }}"
  database_url: "postgresql://..."
  
  # IP allowlisting
  allowed_ips:
    - "192.168.10.0/24"  # Internal network only
  
  # Rate limiting
  global_rate_limit:
    requests_per_minute: 1000
    requests_per_hour: 50000
```

### 4. Monitoring and Alerting

#### Key Usage Monitoring
```sql
-- Monitor unusual key activity
SELECT key_alias, COUNT(*) as request_count, 
       DATE_TRUNC('hour', created_at) as hour
FROM litellm_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY key_alias, hour
HAVING COUNT(*) > 1000;  -- Alert threshold
```

#### Security Alerts
- Failed authentication attempts > 10/minute
- New IP address using existing key
- Requests outside business hours
- Model access pattern changes

### 5. Secure Configuration

#### Environment Variables
```bash
# NEVER hardcode keys
# BAD:
OPENAI_API_KEY="sk-1234567890abcdef"

# GOOD:
OPENAI_API_KEY="${LITELLM_CLIENT_KEY}"
```

#### Configuration Files
```yaml
# Use Ansible Vault for sensitive data
litellm_master_key: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  66383439383437663...
```

### 6. Audit Trail

#### Enable Comprehensive Logging
```yaml
general_settings:
  # Log all API calls
  log_level: "INFO"
  log_to_file: true
  log_file_path: "/var/log/litellm/audit.log"
  
  # Include request details
  log_request_headers: true
  log_request_body: false  # PII protection
  log_response_body: false
```

#### Log Retention
- API logs: 90 days
- Security events: 365 days
- Key operations: Permanent

## 🚨 Incident Response

### If Master Key is Compromised

1. **Immediate Actions** (< 5 minutes):
   ```bash
   # Disable the service
   ssh api-server "sudo systemctl stop litellm"
   
   # Block network access
   ssh api-server "sudo iptables -I INPUT -p tcp --dport 4000 -j DROP"
   ```

2. **Rotate Keys** (< 30 minutes):
   - Generate new master key
   - Update all virtual keys
   - Deploy new configuration
   - Resume service

3. **Post-Incident**:
   - Review audit logs
   - Identify exposure window
   - Notify affected users
   - Update security procedures

## 📋 Security Checklist

### Pre-Deployment
- [ ] Database configured for virtual keys
- [ ] Master key stored in Ansible Vault
- [ ] Network firewall rules in place
- [ ] SSL/TLS certificates ready

### Deployment
- [ ] Virtual keys generated for all clients
- [ ] Master key NOT in any client config
- [ ] Monitoring alerts configured
- [ ] Audit logging enabled

### Post-Deployment
- [ ] Key rotation schedule documented
- [ ] Security runbook created
- [ ] Incident response plan tested
- [ ] Regular security audits scheduled

## 🔧 Implementation Commands

### 1. Deploy Database Support
```bash
ansible-playbook playbooks/Lite-LLM/litellm_database_setup.yml
```

### 2. Generate Virtual Keys
```bash
# For each client application
./scripts/generate_virtual_key.sh "client-name" "90d"
```

### 3. Update Client Configurations
```bash
# Update Open WebUI
ansible-playbook playbooks/update_webui_virtual_key.yml
```

### 4. Verify Security
```bash
# Check for master key exposure
grep -r "sk-1234567890abcdef" /etc/ || echo "✅ No master key found"

# Verify virtual keys working
curl -H "Authorization: Bearer $VIRTUAL_KEY" http://api:4000/v1/models
```

## 📚 References

- [LiteLLM Virtual Keys Documentation](https://docs.litellm.ai/docs/proxy/virtual_keys)
- [PostgreSQL Security Best Practices](https://www.postgresql.org/docs/current/security.html)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)

---

**Document Version**: 1.0  
**Last Updated**: September 16, 2025  
**Classification**: INTERNAL - SECURITY SENSITIVE