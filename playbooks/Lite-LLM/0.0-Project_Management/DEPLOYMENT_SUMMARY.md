# LiteLLM Deployment Summary Guide

## Overview

This guide summarizes the complete LiteLLM deployment process, including all configuration scripts from Tasks 4-9.

## Deployment Architecture

```
┌─────────────────┐        ┌──────────────────┐       ┌─────────────────────┐
│ hx-devops-server│───────▶│ hx-api-server    │──────▶│ hx-llm01/02-server  │
│ (Control Node)  │        │ (LiteLLM Gateway)│       │ (Ollama Backends)   │
└─────────────────┘        └──────────────────┘       └─────────────────────┘
                                     │
                                     ▼
                           ┌──────────────────┐
                           │ hx-webui-server  │
                           │ (Open WebUI)     │
                           └──────────────────┘
```

## Deployment Steps

### Phase 1: Infrastructure Setup (Tasks 4-5)
**Location**: Run on `hx-devops-server`

1. **Task 4**: Configure Ansible inventory and group variables
   - Add `[litellm]` and `[llm]` groups to inventory
   - Create LiteLLM configuration variables
   - Set up encrypted vault with master key

2. **Task 5**: Create Ansible role `hx_litellm_proxy`
   - Template configuration files
   - Define systemd service unit
   - Set up virtual environment structure

### Phase 2: Service Deployment (Task 6)
**Location**: Run on `hx-devops-server`, deploys to `hx-api-server`

3. **Task 6**: Deploy LiteLLM service
   - Run Ansible playbook to install and configure
   - Verify service is running
   - Test authentication and API endpoints

### Phase 3: Integration (Tasks 7-9)
**Location**: Run on `hx-devops-server`, configures `hx-webui-server`

4. **Task 7**: Configure Open WebUI
   - Update environment file with LiteLLM gateway settings
   - Set `OPENAI_API_BASE_URL` and `OPENAI_API_KEY`

5. **Task 8**: Restart and verify Open WebUI
   - Restart service to apply changes
   - Verify configuration persistence

6. **Task 9**: Test OpenAI-compatible clients
   - Test with curl commands
   - Test with Python OpenAI SDK

## Quick Deployment Commands

### Complete deployment in one go:
```bash
# From hx-devops-server
cd ~/hx-ansible

# Run Tasks 4-6 (infrastructure + deployment)
./playbooks/Lite-LLM/0.0-Project_Management/deployment_scripts_batch1-2.sh

# Run Tasks 7-9 (integration + verification)  
./playbooks/Lite-LLM/0.0-Project_Management/deployment_scripts_batch3.sh
```

### Individual task execution:
```bash
# Deploy only LiteLLM service
ansible-playbook -i inventories/dev.ini playbooks/litellm_enforce.yml \
  --limit hx-api-server

# Test the API
export LITELLM_API_KEY="sk-1234567890abcdef-test-key-please-replace"
curl -H "Authorization: Bearer $LITELLM_API_KEY" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models
```

## Key Configuration Files

### 1. Ansible Inventory (`inventories/dev.ini`)
```ini
[litellm]
hx-api-server.dev-test.hana-x.ai

[llm]
hx-llm01-server.dev-test.hana-x.ai
hx-llm02-server.dev-test.hana-x.ai
```

### 2. Group Variables (`inventories/group_vars/all/litellm.yml`)
```yaml
litellm_bind_host: "0.0.0.0"
litellm_bind_port: 4000
litellm_base_url: "http://hx-api-server.dev-test.hana-x.ai:4000"
litellm_backends:
  - "http://hx-llm01-server.dev-test.hana-x.ai:11434"
  - "http://hx-llm02-server.dev-test.hana-x.ai:11434"
```

### 3. Service Configuration (`/etc/litellm/config.yaml`)
- Model definitions with Ollama provider
- Load balancing: "least-busy" strategy
- Authentication via master key

## Verification Steps

### 1. Service Health
```bash
ssh hx-api-server sudo systemctl status litellm
ssh hx-api-server sudo journalctl -u litellm -f
```

### 2. API Functionality
```bash
# List models
curl -H "Authorization: Bearer $LITELLM_API_KEY" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models

# Chat completion
curl -X POST http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "phi3-3.8b", "messages": [{"role": "user", "content": "Hello"}]}'
```

### 3. Open WebUI Integration
- Access Open WebUI at: http://hx-webui-server.dev-test.hana-x.ai
- Models should appear in the model selector
- Chat functionality should work through the gateway

## Troubleshooting

### Common Issues

1. **Service won't start**
   - Check: `sudo journalctl -u litellm -n 50`
   - Verify Python 3.11/3.12 is installed
   - Check file permissions on `/etc/litellm/`

2. **Authentication errors**
   - Ensure API key is included in Authorization header
   - Format: `Authorization: Bearer sk-...`

3. **Models not appearing**
   - Verify Ollama backends are running
   - Check backend connectivity from API server
   - Ensure models are pulled on Ollama servers

### Support Commands
```bash
# Check all services
for host in hx-api-server hx-llm01-server hx-llm02-server hx-webui-server; do
  echo "=== $host ==="
  ssh $host "sudo systemctl status litellm ollama open-webui 2>/dev/null | grep -E '(Active:|●)'"
done

# Test backend connectivity
ssh hx-api-server "curl -s http://hx-llm01-server.dev-test.hana-x.ai:11434/api/tags | jq -r '.models[].name' | head -5"
```

## Security Notes

1. **Master Key**: Currently using test key `sk-1234567890abcdef-test-key-please-replace`
   - Should be rotated for production use
   - Store in Ansible Vault for security

2. **Network Security**:
   - Consider implementing firewall rules
   - Use internal networks for backend communication
   - Enable HTTPS for production deployments

3. **Access Control**:
   - Implement proper API key management
   - Consider rate limiting per key
   - Monitor usage patterns

## Next Steps

1. **Production Readiness**:
   - Rotate master key
   - Set up monitoring/alerting
   - Configure backup strategy
   - Implement log rotation

2. **Feature Enhancements**:
   - Add more models
   - Configure response caching
   - Set up database for key management
   - Implement usage analytics

3. **Integration Expansion**:
   - Connect additional clients
   - Set up CI/CD pipelines
   - Create API documentation
   - Build custom integrations

---

**Last Updated**: September 16, 2025  
**Version**: 1.0  
**Maintained by**: HX Infrastructure Team