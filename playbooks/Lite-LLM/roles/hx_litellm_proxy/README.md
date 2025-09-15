# Ansible Role: hx_litellm_proxy

Deploy and configure LiteLLM as an OpenAI-compatible proxy for Ollama backends.

## Requirements

- **Ansible**: 2.17 or higher (ansible-core)
- **Python**: 3.8 or higher on the target host
- **Systemd**: For service management
- **Network**: Access to Ollama backend servers

### Ansible Version Note

This role requires ansible-core 2.17 or higher. If you're using an older version, you'll need to upgrade:

```bash
# Upgrade ansible-core
pip install --upgrade ansible-core>=2.17

# Or install the full Ansible package (includes ansible-core)
pip install --upgrade ansible>=9.0
```

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

```yaml
# Service configuration
litellm_service_name: litellm
litellm_service_user: litellm
litellm_service_group: litellm
litellm_service_description: "LiteLLM OpenAI Proxy"

# Network binding
litellm_bind_host: "0.0.0.0"
litellm_bind_port: 4000

# Backend configuration
litellm_backends:
  - "http://hx-llm01-server.dev-test.hana-x.ai:11434"
  - "http://hx-llm02-server.dev-test.hana-x.ai:11434"

# Model configuration
litellm_models:
  - name: "phi3-3.8b"
    provider: "ollama"
    model: "phi3:3.8b-mini-128k-instruct-q8_0"

# Security
litellm_master_key: ""  # Set this in vault!
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: api_servers
  become: yes
  roles:
    - role: hx_litellm_proxy
      vars:
        litellm_bind_port: 8080
        litellm_master_key: "{{ vault_litellm_master_key }}"
```

## Service Management

The role installs LiteLLM as a systemd service:

```bash
# Check service status
systemctl status litellm

# View logs
journalctl -u litellm -f

# Restart service
systemctl restart litellm
```

## API Usage

Once deployed, the LiteLLM proxy provides an OpenAI-compatible API:

```bash
# Test the API
curl http://localhost:4000/v1/models

# Make a completion request
curl http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -d '{
    "model": "phi3-3.8b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## License

MIT

## Author Information

Created by the HX Infrastructure Team at HanaX AI.