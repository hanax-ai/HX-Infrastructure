# LiteLLM Playbook Inventory Requirements

## Overview
The LiteLLM playbooks use flexible host targeting to support multiple environments without modifying the playbooks.

## Inventory Groups

### Required Groups
The following inventory groups should be defined for LiteLLM deployments:

1. **`litellm_servers`** - Primary group for LiteLLM proxy servers
2. **`api`** - Alternative group name (for backward compatibility)

### Example Inventory Structure
```ini
[litellm_servers]
hx-api-server.dev-test.hana-x.ai ansible_user=agent0
# Add additional LiteLLM servers here for multi-node deployments

[api]
hx-api-server.dev-test.hana-x.ai ansible_user=agent0

# For production environments
[litellm_servers:vars]
ansible_user=agent0
litellm_environment=production
```

## Usage Examples

### Using Default Group (api)
```bash
ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml -i inventories/dev.ini
```

### Using Specific Group
```bash
ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml -i inventories/dev.ini -e "target_hosts=litellm_servers"
```

### Targeting Specific Host
```bash
ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml -i inventories/dev.ini -e "target_hosts=hx-api-server.dev-test.hana-x.ai"
```

### Multiple Environments
```bash
# Development
ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml -i inventories/dev.ini

# Staging
ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml -i inventories/staging.ini

# Production
ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml -i inventories/prod.ini
```

## Variables

### target_hosts
- **Type**: String
- **Default**: `api`
- **Description**: Specifies which hosts or groups to target
- **Usage**: `-e "target_hosts=litellm_servers"`

## CI/CD Integration

For automated deployments, pass the appropriate inventory and target:

```yaml
# Example GitLab CI
deploy_litellm:
  script:
    - ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml \
        -i inventories/${ENVIRONMENT}.ini \
        -e "target_hosts=litellm_servers"
```

```yaml
# Example GitHub Actions
- name: Run LiteLLM Preflight
  run: |
    ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml \
      -i inventories/${{ matrix.environment }}.ini \
      -e "target_hosts=litellm_servers"
```

## Best Practices

1. **Use inventory groups** rather than hardcoded hostnames
2. **Define environment-specific inventories** (dev.ini, staging.ini, prod.ini)
3. **Use group_vars** for environment-specific configurations
4. **Document any custom groups** in your inventory files
5. **Test with --list-hosts** before running:
   ```bash
   ansible-playbook playbooks/Lite-LLM/litellm_preflight.yml -i inventories/dev.ini --list-hosts
   ```