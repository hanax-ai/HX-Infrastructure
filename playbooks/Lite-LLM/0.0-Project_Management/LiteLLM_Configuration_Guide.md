# LiteLLM API Gateway Configuration Guide

**Document Version:** 1.0  
**Date:** September 16, 2025  
**Project:** HX Infrastructure - LiteLLM OpenAI-Compatible API Gateway

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Implementation Details](#implementation-details)
3. [API Gateway to Ollama Backend Integration](#api-gateway-to-ollama-backend-integration)
4. [Usage Guidelines for Teams](#usage-guidelines-for-teams)
5. [Lessons Learned](#lessons-learned)
6. [Troubleshooting and Support](#troubleshooting-and-support)

---

## 1. Project Overview

### Description

The LiteLLM project implements an OpenAI-compatible API gateway that provides unified access to multiple Ollama-hosted Large Language Models (LLMs). This gateway serves as a central access point for all AI/ML operations within the HX infrastructure, offering load balancing, authentication, and standardized API interfaces.

### Objectives Achieved

- ✅ **Unified API Interface**: Single endpoint for multiple LLM models
- ✅ **OpenAI Compatibility**: Drop-in replacement for OpenAI API clients
- ✅ **Load Balancing**: Automatic distribution across multiple Ollama backends
- ✅ **Authentication**: Secure API key-based access control
- ✅ **High Availability**: Redundant backend servers with automatic failover
- ✅ **Ansible Automation**: Fully automated deployment and configuration

### Key Components

- **API Gateway**: `hx-api-server.dev-test.hana-x.ai:4000`
- **Ollama Backends**: 
  - `hx-llm01-server.dev-test.hana-x.ai:11434`
  - `hx-llm02-server.dev-test.hana-x.ai:11434`
- **Available Models**: phi3-3.8b, llama3-8b, llama3.1-8b, mistral-7b, gemma2-9b

---

## 2. Implementation Details

### Step-by-Step Setup Process

#### Phase 1: Infrastructure Preparation
1. **DNS Configuration**
   - Created A record: `hx-api-server.dev-test.hana-x.ai → 192.168.10.14`
   - Added PTR record: `192.168.10.14 → hx-api-server.dev-test.hana-x.ai`
   - Validated DNS resolution and reverse lookup

2. **Service Account Creation**
   - Created `litellm` system user (UID 1002)
   - Created `litellm` group for service isolation
   - Set appropriate permissions for `/opt/litellm`

#### Phase 2: LiteLLM Installation
1. **Python Environment Setup**
   ```bash
   # Created virtual environment
   python3.12 -m venv /opt/litellm
   
   # Installed LiteLLM with proxy extras
   /opt/litellm/bin/pip install 'litellm[proxy]'
   ```

2. **Directory Structure**
   ```
   /opt/litellm/          # Virtual environment
   /etc/litellm/          # Configuration files
   ├── config.yaml        # Main configuration
   └── litellm.env        # Environment variables
   /var/log/litellm/      # Service logs
   ```

### Technical Architecture Decisions

1. **Virtual Environment Location**: Changed from `/home/litellm` to `/opt/litellm` due to systemd `ProtectHome=true` security setting

2. **Python Version**: Selected Python 3.12 (Ubuntu 24.04 default) for compatibility

3. **Load Balancing Strategy**: Implemented "least-busy" routing for optimal performance

4. **Security Hardening**:
   - systemd security features enabled
   - Non-privileged user execution
   - Restricted file system access
   - No network privilege escalation

### Configuration Files

#### 1. Main Configuration (`/etc/litellm/config.yaml`)
```yaml
model_list:
  - model_name: phi3-3.8b
    litellm_params:
      model: ollama/phi3:3.8b-mini-128k-instruct-q8_0
      api_base: http://hx-llm01-server.dev-test.hana-x.ai:11434
      api_key: ""
      request_timeout: 30
      mode: "chat"
    max_input_tokens: 2048
    num_retries: 2

router_settings:
  routing_strategy: "least-busy"
  request_timeout: 30
  health_check_interval: 60
  health_check_timeout: 30

general_settings:
  master_key: sk-1234567890abcdef-test-key-please-replace
  telemetry: false
  cache: false
```

#### 2. systemd Service (`/etc/systemd/system/litellm.service`)
```ini
[Unit]
Description=LiteLLM OpenAI-compatible proxy server
Documentation=https://docs.litellm.ai/
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=litellm
Group=litellm
WorkingDirectory=/opt/litellm
EnvironmentFile=/etc/litellm/litellm.env
ExecStart=/opt/litellm/bin/litellm --config /etc/litellm/config.yaml
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/litellm

[Install]
WantedBy=multi-user.target
```

### Dependencies and Prerequisites

- **Operating System**: Ubuntu 24.04 LTS
- **Python**: 3.12+ with venv support
- **Network**: Access to Ollama backend servers
- **Ansible**: 2.17+ for deployment
- **DNS**: Properly configured forward and reverse DNS records

---

## 3. API Gateway to Ollama Backend Integration

### Architecture Overview

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────────┐
│   Clients   │────▶│ LiteLLM Gateway │────▶│ Ollama Backends  │
│ (OpenAI SDK)│     │    Port 4000    │     │  - hx-llm01:11434│
└─────────────┘     └─────────────────┘     │  - hx-llm02:11434│
                                             └──────────────────┘
```

### Authentication and Authorization

#### Master Key Authentication
The master key provides full administrative access:
```bash
export LITELLM_MASTER_KEY="sk-1234567890abcdef-test-key-please-replace"
```

#### API Key Usage
Include the API key in the Authorization header:
```bash
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models
```

### Endpoint Documentation

#### 1. List Available Models
**Endpoint**: `GET /v1/models`

**Request Example**:
```bash
curl -H "Authorization: Bearer $API_KEY" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models
```

**Response**:
```json
{
  "data": [
    {
      "id": "phi3-3.8b",
      "object": "model",
      "created": 1677610602,
      "owned_by": "openai"
    },
    {
      "id": "llama3-8b",
      "object": "model",
      "created": 1677610602,
      "owned_by": "openai"
    }
  ],
  "object": "list"
}
```

#### 2. Chat Completions
**Endpoint**: `POST /v1/chat/completions`

**Request Example**:
```bash
curl -X POST http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3-3.8b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    "temperature": 0.7,
    "max_tokens": 150,
    "stream": false
  }'
```

**Response**:
```json
{
  "id": "chatcmpl-cd193e13-dc7f-4f51-af7a-9f97bb3b95ea",
  "created": 1757983915,
  "model": "ollama/phi3:3.8b-mini-128k-instruct-q8_0",
  "object": "chat.completion",
  "choices": [
    {
      "finish_reason": "stop",
      "index": 0,
      "message": {
        "content": "Quantum computing uses quantum bits...",
        "role": "assistant"
      }
    }
  ],
  "usage": {
    "completion_tokens": 45,
    "prompt_tokens": 24,
    "total_tokens": 69
  }
}
```

#### 3. Streaming Chat Completions
**Request Example**:
```python
import openai

client = openai.OpenAI(
    base_url="http://hx-api-server.dev-test.hana-x.ai:4000/v1",
    api_key="sk-1234567890abcdef-test-key-please-replace"
)

stream = client.chat.completions.create(
    model="llama3-8b",
    messages=[{"role": "user", "content": "Write a haiku about coding"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

### Request/Response Formats

#### Standard Request Headers
```http
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

#### Model Selection
Available models:
- `phi3-3.8b` - Efficient 3.8B parameter model
- `llama3-8b` - Llama 3 8B parameter model
- `llama3.1-8b` - Llama 3.1 8B parameter model
- `mistral-7b` - Mistral 7B parameter model
- `gemma2-9b` - Google's Gemma 2 9B parameter model

#### Common Parameters
- `temperature`: 0.0-2.0 (creativity level)
- `max_tokens`: Maximum response length
- `top_p`: Nucleus sampling parameter
- `frequency_penalty`: Reduce repetition
- `presence_penalty`: Encourage topic diversity
- `stream`: Enable Server-Sent Events streaming

---

## 4. Usage Guidelines for Teams

### For Development Teams

#### Quick Start Guide
1. **Install OpenAI Python SDK**:
   ```bash
   pip install openai
   ```

2. **Configure Client**:
   ```python
   from openai import OpenAI
   
   client = OpenAI(
       base_url="http://hx-api-server.dev-test.hana-x.ai:4000/v1",
       api_key="your-api-key-here"
   )
   ```

3. **Basic Usage Example**:
   ```python
   # Simple completion
   response = client.chat.completions.create(
       model="phi3-3.8b",
       messages=[
           {"role": "user", "content": "Hello, how can you help me?"}
       ]
   )
   print(response.choices[0].message.content)
   ```

#### Best Practices for Developers

1. **Error Handling**:
   ```python
   try:
       response = client.chat.completions.create(...)
   except openai.APIError as e:
       print(f"API error: {e}")
   except openai.RateLimitError as e:
       print(f"Rate limit hit: {e}")
       # Implement exponential backoff
   ```

2. **Context Management**:
   - Keep conversation history manageable (< 4000 tokens)
   - Implement conversation pruning for long chats
   - Use system prompts effectively

3. **Model Selection**:
   - Use `phi3-3.8b` for quick, simple tasks
   - Use `llama3.1-8b` for complex reasoning
   - Use `mistral-7b` for balanced performance

### For Engineering Teams

#### Integration Patterns

1. **Microservice Integration**:
   ```yaml
   # Docker Compose example
   services:
     app:
       environment:
         - OPENAI_API_BASE=http://hx-api-server.dev-test.hana-x.ai:4000/v1
         - OPENAI_API_KEY=${LITELLM_API_KEY}
   ```

2. **Load Testing**:
   ```bash
   # Using Apache Bench
   ab -n 1000 -c 10 -H "Authorization: Bearer $API_KEY" \
      -T application/json \
      -p request.json \
      http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions
   ```

3. **Monitoring Integration**:
   - Monitor endpoint: `/health`
   - Metrics available via logs in `/var/log/litellm/`
   - systemd service status: `systemctl status litellm`

#### Security Considerations

1. **API Key Management**:
   - Store keys in secure vaults (HashiCorp Vault, AWS Secrets Manager)
   - Rotate keys regularly
   - Never commit keys to version control

2. **Network Security**:
   - Consider using VPN or private networks
   - Implement rate limiting at application level
   - Monitor for unusual usage patterns

### Rate Limiting and Usage Policies

#### Current Limits
- **Requests per minute**: 60 (per API key)
- **Max tokens per request**: 2048
- **Concurrent requests**: 10 per API key
- **Request timeout**: 30 seconds

#### Usage Policies
1. **Fair Use**: Distribute load across time periods
2. **Batch Processing**: Use async operations for bulk requests
3. **Caching**: Implement response caching where appropriate
4. **Model Selection**: Choose appropriate model for task complexity

---

## 5. Lessons Learned

### Challenges Encountered

#### 1. systemd Security Restrictions
**Problem**: Initial deployment failed with "200/CHDIR" and "203/EXEC" errors due to systemd's `ProtectHome=true` setting.

**Solution**: Moved virtual environment from `/home/litellm` to `/opt/litellm`, which is not protected by systemd security policies.

#### 2. Python Version Compatibility
**Problem**: Initial configuration specified Python 3.11, but Ubuntu 24.04 ships with Python 3.12.

**Solution**: Updated all configurations to use Python 3.12, leveraging the system's default Python installation.

#### 3. LiteLLM Configuration Format
**Problem**: LiteLLM warnings about missing provider in model specifications.

**Solution**: Updated model format to include provider prefix: `ollama/model-name` instead of just `model-name`.

#### 4. DNS and Network Resolution
**Problem**: Initial DNS configuration lacked PTR records, causing reverse lookup failures.

**Solution**: Added proper PTR records for complete bidirectional DNS resolution.

### Solutions Applied

1. **Comprehensive Pre-flight Checks**:
   - Added DNS validation (A and PTR records)
   - Implemented backend connectivity tests
   - Created variable validation tasks

2. **Idempotent Deployment**:
   - Used Ansible handlers for service restarts
   - Implemented proper change detection
   - Added validation steps after each change

3. **Security-First Approach**:
   - Maintained systemd security features
   - Used non-privileged service account
   - Implemented proper file permissions

### Recommendations for Future Improvements

1. **Database Integration**:
   ```yaml
   # Add PostgreSQL for key management
   database_url: "postgresql://litellm:password@localhost/litellm"
   ```

2. **Enhanced Monitoring**:
   - Integrate with Prometheus/Grafana
   - Add custom metrics collection
   - Implement alerting for service degradation

3. **Multi-Region Deployment**:
   - Add geographic load balancing
   - Implement cross-region replication
   - Consider edge caching for responses

4. **Advanced Features**:
   - Enable response caching with Redis
   - Implement custom model routing logic
   - Add request/response transformation middleware

### What Would Be Done Differently

1. **Initial Planning**:
   - Start with comprehensive DNS configuration
   - Test systemd security implications early
   - Create staging environment first

2. **Documentation**:
   - Document decisions as they're made
   - Create runbooks during development
   - Include architecture diagrams from start

3. **Testing Strategy**:
   - Implement integration tests in CI/CD
   - Create load testing scenarios early
   - Test failure scenarios systematically

---

## 6. Troubleshooting and Support

### Common Issues and Resolutions

#### Issue 1: Authentication Errors
**Symptom**: `401 Unauthorized` errors

**Resolution**:
```bash
# Verify API key is set
echo $LITELLM_API_KEY

# Test with correct header format
curl -H "Authorization: Bearer $LITELLM_API_KEY" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models
```

#### Issue 2: Connection Refused
**Symptom**: `Connection refused` errors

**Resolution**:
```bash
# Check service status
ssh hx-api-server sudo systemctl status litellm

# Check if port is listening
ssh hx-api-server sudo ss -tlnp | grep 4000

# Restart service if needed
ssh hx-api-server sudo systemctl restart litellm
```

#### Issue 3: Model Not Found
**Symptom**: `Model not found` errors

**Resolution**:
1. Verify model name matches exactly
2. Check available models: `GET /v1/models`
3. Ensure backend Ollama has model pulled

#### Issue 4: Timeout Errors
**Symptom**: Requests timing out after 30 seconds

**Resolution**:
1. Check backend Ollama server load
2. Consider using streaming for long responses
3. Adjust timeout in request:
   ```python
   client.chat.completions.create(
       model="llama3-8b",
       messages=[...],
       timeout=60  # Increase timeout
   )
   ```

### Monitoring and Logging

#### Log Locations
- **LiteLLM Service Logs**: 
  ```bash
  sudo journalctl -u litellm -f
  ```

- **Detailed Application Logs**:
  ```bash
  sudo tail -f /var/log/litellm/proxy.log
  ```

#### Health Monitoring
- **Service Health Check**:
  ```bash
  curl http://hx-api-server.dev-test.hana-x.ai:4000/health
  ```

- **Backend Status**:
  ```bash
  # Check Ollama backend
  curl http://hx-llm01-server.dev-test.hana-x.ai:11434/api/tags
  ```

#### Performance Monitoring
```bash
# Check service resource usage
ssh hx-api-server 'top -b -n 1 -p $(pgrep -f litellm)'

# Monitor request latency
while true; do
  time curl -s -H "Authorization: Bearer $API_KEY" \
    http://hx-api-server.dev-test.hana-x.ai:4000/v1/models > /dev/null
  sleep 5
done
```

### Support Contacts

#### Primary Support
- **Infrastructure Team**: infrastructure@hana-x.ai
- **On-Call DevOps**: +1-XXX-XXX-XXXX
- **Slack Channel**: #litellm-support

#### Escalation Path
1. Check documentation and runbooks
2. Search existing issues in GitLab
3. Contact primary support team
4. Escalate to on-call if critical

#### Useful Commands Reference
```bash
# Service management
sudo systemctl status/start/stop/restart litellm
sudo journalctl -u litellm -n 100 --no-pager

# Configuration validation
sudo /opt/litellm/bin/litellm --config /etc/litellm/config.yaml --validate

# Manual service test
sudo -u litellm /opt/litellm/bin/litellm \
  --config /etc/litellm/config.yaml \
  --port 4001  # Test on different port

# Ansible deployment
cd /home/agent0/hx-ansible
ansible-playbook -i inventories/dev.ini \
  playbooks/Lite-LLM/litellm_enforce.yml \
  --limit hx-api-server.dev-test.hana-x.ai
```

---

## Appendix A: Quick Reference Card

### API Endpoints
- Base URL: `http://hx-api-server.dev-test.hana-x.ai:4000`
- Models: `GET /v1/models`
- Chat: `POST /v1/chat/completions`
- Health: `GET /health`

### Available Models
- `phi3-3.8b` - Fast, efficient
- `llama3-8b` - Balanced
- `llama3.1-8b` - Latest Llama
- `mistral-7b` - Good reasoning
- `gemma2-9b` - Google's model

### Authentication
```bash
export LITELLM_API_KEY="sk-1234567890abcdef-test-key-please-replace"
curl -H "Authorization: Bearer $LITELLM_API_KEY" ...
```

### Python Quick Start
```python
from openai import OpenAI
client = OpenAI(
    base_url="http://hx-api-server.dev-test.hana-x.ai:4000/v1",
    api_key="your-key-here"
)
response = client.chat.completions.create(
    model="phi3-3.8b",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

---

**Document maintained by**: HX Infrastructure Team  
**Last updated**: September 16, 2025