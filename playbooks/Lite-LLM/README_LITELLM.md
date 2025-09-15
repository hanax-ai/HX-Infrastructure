# LiteLLM Deployment Guide

This guide provides step-by-step instructions for deploying LiteLLM as an OpenAI-compatible proxy for Ollama backends in the HX Infrastructure.

## Overview

LiteLLM will be deployed on `hx-api-server.dev-test.hana-x.ai` to provide:
- OpenAI-compatible API at `http://hx-api-server.dev-test.hana-x.ai:4000/v1`
- Load balancing across multiple Ollama backends (`hx-llm01-server` and `hx-llm02-server`)
- Master key authentication for API access
- Model aliasing for consistent naming

## Playbook Structure

The deployment is broken down into the following executable playbooks:

### 1. Pre-Flight Checks (`litellm_preflight.yml`)
**Purpose**: Validates all prerequisites before deployment
- DNS resolution checks
- Network configuration validation
- Domain join and privileges verification
- CA trust chain validation
- Python 3.11 runtime checks
- Saves evidence to `.evidence/api-preflight/<timestamp>/`

**Run with**:
```bash
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_preflight.yml
```

### 2. Inventory Setup (`litellm_inventory_setup.yml`)
**Purpose**: Configures inventory and group variables
- Adds `[litellm]` group to inventory
- Configures non-secret variables in `group_vars/all/main.yml`
- Quarantines stray vault files
- Provides instructions for vault configuration

**Run with**:
```bash
ansible-playbook playbooks/Lite-LLM/litellm_inventory_setup.yml
```

**Manual step required**: After running, add the master key to vault:
```bash
# Generate a secure master key
openssl rand -hex 32 | sed 's/^/sk-/'

# Add to vault
ansible-vault edit inventories/group_vars/all/vault.yml

# Add this line:
litellm_master_key: "sk-YOUR-GENERATED-KEY-HERE"
```

### 3. Role Validation (`litellm_role_validation.yml`)
**Purpose**: Creates and validates the Ansible role structure
- Creates `roles/hx_litellm_proxy/` directory structure
- Generates template files
- Validates template rendering
- Saves test renders to `.evidence/litellm_role_validation/<timestamp>/`

**Run with**:
```bash
ansible-playbook playbooks/Lite-LLM/litellm_role_validation.yml
```

### 4. LiteLLM Deployment (`litellm_enforce.yml`)
**Purpose**: Main deployment playbook
- Deploys LiteLLM proxy using the `hx_litellm_proxy` role
- Configures systemd service
- Validates deployment
- Saves evidence to `.evidence/litellm_deployment_<timestamp>.txt`

**Run with**:
```bash
# Dry run first
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_enforce.yml \
  --limit hx-api-server --check --diff

# Actual deployment
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_enforce.yml \
  --limit hx-api-server --ask-vault-pass
```

### 5. Smoke Tests (`litellm_smoke_test.yml`)
**Purpose**: Comprehensive post-deployment validation
- Connectivity tests
- Authentication verification
- Model listing
- Chat completion tests
- Streaming validation
- Load balancing verification
- Performance testing
- Saves report to `.evidence/litellm_smoke_<timestamp>/`

**Run with**:
```bash
ansible-playbook playbooks/Lite-LLM/litellm_smoke_test.yml --ask-vault-pass
```

## Complete Deployment Sequence

Execute the playbooks in this order:

```bash
# 1. Run pre-flight checks
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_preflight.yml

# 2. Setup inventory and variables
ansible-playbook playbooks/Lite-LLM/litellm_inventory_setup.yml

# 3. Add master key to vault (manual step)
ansible-vault edit inventories/group_vars/all/vault.yml

# 4. Validate role structure
ansible-playbook playbooks/Lite-LLM/litellm_role_validation.yml

# 5. Deploy LiteLLM (dry run)
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_enforce.yml \
  --limit hx-api-server --check --diff

# 6. Deploy LiteLLM (actual)
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_enforce.yml \
  --limit hx-api-server --ask-vault-pass

# 7. Run smoke tests
ansible-playbook playbooks/Lite-LLM/litellm_smoke_test.yml --ask-vault-pass
```

## Project Structure

The complete LiteLLM project is organized as follows:

```
playbooks/Lite-LLM/
├── README_LITELLM.md              # This deployment guide
├── STRUCTURE.md                   # Detailed structure documentation
│
├── litellm_preflight.yml          # Pre-flight checks playbook
├── litellm_inventory_setup.yml    # Inventory and group vars setup
├── litellm_role_validation.yml    # Role structure validation
├── litellm_enforce.yml            # Main deployment playbook
├── litellm_smoke_test.yml         # Post-deployment testing
│
├── roles/
│   └── hx_litellm_proxy/          # Ansible role for LiteLLM
│       ├── defaults/main.yml      # Default variables
│       ├── handlers/main.yml      # Service restart handlers
│       ├── meta/main.yml          # Role metadata
│       ├── tasks/
│       │   ├── main.yml          # Main deployment tasks
│       │   └── systemd.yml       # Systemd service configuration
│       └── templates/
│           ├── litellm.config.yaml.j2  # LiteLLM configuration
│           └── litellm.env.j2          # Environment variables
│
├── x-plan/                        # Planning and design documents
│   └── LiteLLM API Gateway — HX API Server_Final.md
│
└── x-tasks/                       # Original task specifications
    ├── task_3.01_preflight_checks.md
    ├── task_3.02_inventory_group_vars.md
    └── task_3.03_role_template_validation.md
```

## Configuration

### Models Configuration
Models are configured in `inventories/group_vars/all/main.yml`:
```yaml
litellm_models:
  - name: "phi3-3.8b"         # Alias name exposed via API
    provider: "ollama"
    model: "phi3:3.8b-mini-128k-instruct-q8_0"  # Actual Ollama model
  - name: "llama3-8b"
    provider: "ollama"
    model: "llama3:8b-instruct-q8_0"
```

### Backend Configuration
```yaml
litellm_backends:
  - "http://hx-llm01-server.dev-test.hana-x.ai:11434"
  - "http://hx-llm02-server.dev-test.hana-x.ai:11434"
```

## Service Management

After deployment, manage the service with:

```bash
# Check status
sudo systemctl status litellm

# View logs
sudo journalctl -u litellm -f

# Restart service
sudo systemctl restart litellm

# Stop service
sudo systemctl stop litellm
```

## API Usage

### List available models
```bash
curl -H "Authorization: Bearer YOUR-MASTER-KEY" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models
```

### Chat completion
```bash
curl -X POST http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions \
  -H "Authorization: Bearer YOUR-MASTER-KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3-3.8b",
    "messages": [{"role": "user", "content": "Hello, world!"}]
  }'
```

## Integration with Open WebUI

1. In Open WebUI, add a new OpenAI-compatible provider
2. Set Base URL: `http://hx-api-server.dev-test.hana-x.ai:4000/v1`
3. Set API Key: Use the master key from vault
4. Test the connection and select available models

## Troubleshooting

### Service won't start
```bash
# Check service status
sudo systemctl status litellm

# Check logs
sudo journalctl -u litellm -n 100

# Validate configuration
sudo -u litellm /home/litellm/litellm-venv/bin/python -c \
  "import yaml; yaml.safe_load(open('/etc/litellm/config.yaml'))"
```

### Authentication failures
- Verify master key in vault matches what you're using
- Check if authentication is required (some endpoints may allow anonymous access)

### Models not appearing
- Ensure Ollama models are pulled on backend servers
- Check model names match exactly between LiteLLM config and Ollama

### Performance issues
- Monitor backend load with `htop` on llm servers
- Check routing strategy in config (should be "least-busy")
- Review concurrent request handling

## Evidence and Audit Trail

All playbooks generate evidence in:
- `.evidence/api-preflight/<timestamp>/` - Pre-flight validation
- `.evidence/litellm_role_validation/<timestamp>/` - Role validation
- `.evidence/litellm_deployment_<timestamp>.txt` - Deployment summary
- `.evidence/litellm_smoke_<timestamp>/` - Test results

## Rollback Procedure

If needed to rollback:

1. Stop the service:
   ```bash
   sudo systemctl stop litellm
   sudo systemctl disable litellm
   ```

2. Remove service files:
   ```bash
   sudo rm /etc/systemd/system/litellm.service
   sudo rm -rf /etc/litellm
   ```

3. In Open WebUI, switch back to direct Ollama connections

## Security Considerations

- Master key is stored encrypted in Ansible vault
- Service runs as unprivileged user `litellm`
- Systemd hardening applied (NoNewPrivileges, ProtectSystem, etc.)
- Configuration files have restricted permissions (0640)
- No external network access required (internal Ollama backends only)

## Future Enhancements

- Add per-user API key management
- Implement rate limiting
- Add Prometheus metrics export
- Configure centralized logging
- Add database backend for usage tracking