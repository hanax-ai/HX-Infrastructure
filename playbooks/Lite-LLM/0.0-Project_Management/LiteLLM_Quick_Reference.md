# LiteLLM API Gateway - Quick Reference Card

## 🚀 Quick Start

### API Endpoint
```
Base URL: http://hx-api-server.dev-test.hana-x.ai:4000
```

### Authentication
```bash
export LITELLM_API_KEY="sk-1234567890abcdef-test-key-please-replace"
```

---

## 📋 Available Models

| Model | Size | Best For |
|-------|------|----------|
| `phi3-3.8b` | 3.8B | Fast responses, simple tasks |
| `llama3-8b` | 8B | Balanced performance |
| `llama3.1-8b` | 8B | Latest Llama, enhanced capabilities |
| `mistral-7b` | 7B | Strong reasoning, coding |
| `gemma2-9b` | 9B | Google's model, diverse tasks |

---

## 🔧 Common Commands

### Test Connection
```bash
curl -H "Authorization: Bearer $LITELLM_API_KEY" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models
```

### Simple Chat Request
```bash
curl -X POST http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3-3.8b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## 🐍 Python SDK

### Install
```bash
pip install openai
```

### Basic Usage
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://hx-api-server.dev-test.hana-x.ai:4000/v1",
    api_key="sk-1234567890abcdef-test-key-please-replace"
)

response = client.chat.completions.create(
    model="phi3-3.8b",
    messages=[{"role": "user", "content": "Explain AI in one sentence"}]
)

print(response.choices[0].message.content)
```

### Streaming Example
```python
stream = client.chat.completions.create(
    model="llama3-8b",
    messages=[{"role": "user", "content": "Write a story"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

---

## 🔍 Service Management

### Check Status
```bash
ssh hx-api-server sudo systemctl status litellm
```

### View Logs
```bash
ssh hx-api-server sudo journalctl -u litellm -f
```

### Restart Service
```bash
ssh hx-api-server sudo systemctl restart litellm
```

---

## 📊 Request Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `model` | string | Model to use | required |
| `messages` | array | Conversation history | required |
| `temperature` | float | Creativity (0.0-2.0) | 1.0 |
| `max_tokens` | int | Max response length | 2048 |
| `stream` | bool | Enable streaming | false |
| `top_p` | float | Nucleus sampling | 1.0 |
| `frequency_penalty` | float | Reduce repetition | 0.0 |
| `presence_penalty` | float | Encourage diversity | 0.0 |

---

## ⚡ Rate Limits

- **Requests per minute**: 60
- **Max tokens per request**: 2048
- **Concurrent requests**: 10
- **Request timeout**: 30 seconds

---

## 🆘 Troubleshooting

### 401 Unauthorized
→ Check API key in Authorization header

### Connection Refused
→ Verify service is running: `systemctl status litellm`

### Model Not Found
→ Check exact model name with GET /v1/models

### Timeout Errors
→ Use streaming or increase timeout in client

---

## 📞 Support

- **Slack**: #litellm-support
- **Email**: infrastructure@hana-x.ai
- **Docs**: This guide + main documentation

---

**Last Updated**: September 16, 2025 | **Version**: 1.0