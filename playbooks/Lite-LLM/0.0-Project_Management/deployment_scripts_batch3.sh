#!/bin/bash
# LiteLLM Deployment Scripts - Batch 3 (Tasks 7-9)
# Integration with Open WebUI and Client Verification
# Generated: September 16, 2025
#
# REQUIRED: Set LITELLM_API_KEY environment variable before running:
#   export LITELLM_API_KEY='your-actual-api-key'
#
# API Key format: sk-<32+ alphanumeric characters>

set -euo pipefail

echo "================================================"
echo "LiteLLM Integration Scripts - Batch 3"
echo "Tasks 7-9: Open WebUI Integration & Verification"
echo "================================================"

# Task 7 — Wire Open WebUI to LiteLLM (discover env file, back up, set OpenAI vars)
echo -e "\n### Task 7: Configuring Open WebUI Integration ###"

# Run from control node
EVID=~/hx-ansible/.evidence/litellm/$(date -u +%Y%m%dT%H%M%SZ); mkdir -p "$EVID"

# Define rollback variables
REMOTE_HOST="hx-webui-server.dev-test.hana-x.ai"
BACKUP_PATH=""
ENV_PATH=""

# Rollback function
rollback_env_file() {
    if [[ -n "$BACKUP_PATH" && -n "$ENV_PATH" ]]; then
        echo -e "\n### ROLLBACK: Restoring Open WebUI environment file ###"
        ssh "$REMOTE_HOST" "bash -lc '
            if [[ -f \"$BACKUP_PATH\" ]]; then
                echo \"Restoring from backup: $BACKUP_PATH\"
                sudo cp -a \"$BACKUP_PATH\" \"$ENV_PATH\"
                echo \"Rollback completed successfully\"
            else
                echo \"WARNING: Backup file not found: $BACKUP_PATH\"
            fi
        '" || echo "WARNING: Rollback failed"
    fi
}

# Install trap for rollback on error or exit (will be disabled on success)
trap rollback_env_file ERR

# 7.1 Discover Open WebUI EnvironmentFile path from systemd
ssh "$REMOTE_HOST" \
  "sudo systemctl cat open-webui | grep -E '^EnvironmentFile=' | head -1" \
  | tee "$EVID/70_openwebui_envfile_line.txt"

# 7.2 Capture the actual path and apply changes (atomic)
REMOTE_OUTPUT=$(ssh "$REMOTE_HOST" 'bash -lc "
  set -euo pipefail
  
  # Discover environment file path
  ENV_LINE=\$(sudo systemctl cat open-webui | grep -E \"^EnvironmentFile=\" | head -1)
  ENV_PATH=\${ENV_LINE#EnvironmentFile=}
  echo \"ENV_PATH=\$ENV_PATH\"
  test -f \"\$ENV_PATH\" || { echo \"ERROR: env file not found at \$ENV_PATH\"; exit 20; }

  # Create deterministic backup filename
  TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
  BACKUP_PATH=\"\$ENV_PATH.\$TIMESTAMP.bak\"
  
  # Backup
  sudo cp -a \"\$ENV_PATH\" \"\$BACKUP_PATH\"
  echo \"BACKUP_PATH=\$BACKUP_PATH\"
  
  # Remove any prior OPENAI_* lines to avoid duplicates
  sudo sed -i -e \"/^OPENAI_API_BASE_URL=/d\" -e \"/^OPENAI_API_KEY=/d\" \"\$ENV_PATH\"

  # Append authoritative settings for LiteLLM gateway (keep Ollama vars untouched)
  sudo tee -a \"\$ENV_PATH\" >/dev/null <<EOF
OPENAI_API_BASE_URL=http://hx-api-server.dev-test.hana-x.ai:4000/v1
OPENAI_API_KEY=sk-1234567890abcdef-test-key-please-replace
EOF

  # Show the resulting OPENAI_* lines
  echo \"--- OPENAI lines in \$ENV_PATH ---\"
  sudo grep -E \"^OPENAI_API_(BASE_URL|KEY)=\" \"\$ENV_PATH\" || true
" ')

# Extract paths from remote output
ENV_PATH=$(echo "$REMOTE_OUTPUT" | grep "^ENV_PATH=" | cut -d= -f2)
BACKUP_PATH=$(echo "$REMOTE_OUTPUT" | grep "^BACKUP_PATH=" | cut -d= -f2)

# Export for caller availability
export OPENWEBUI_ENV_BACKUP_PATH="$BACKUP_PATH"
export OPENWEBUI_ENV_PATH="$ENV_PATH"

# Save output
echo "$REMOTE_OUTPUT" | tee "$EVID/71_openwebui_envfile_after.txt"

# If we reach here, the operation was successful - disable trap
trap - ERR | tee "$EVID/71_openwebui_envfile_after.txt"

# Task 8 — Restart Open WebUI and verify it picked up the gateway settings
echo -e "\n### Task 8: Restarting Open WebUI ###"

# 8.1 Restart service cleanly
ssh hx-webui-server.dev-test.hana-x.ai \
  "sudo systemctl daemon-reload && sudo systemctl restart open-webui && sleep 2 && sudo systemctl status --no-pager open-webui" \
  | tee "$EVID/80_openwebui_status_after_restart.txt"

# 8.2 Re-confirm the environment file still contains correct values
ssh hx-webui-server.dev-test.hana-x.ai 'bash -lc "
  ENV_PATH=\$(sudo systemctl cat open-webui | awk -F= \"/^EnvironmentFile=/{print \$2; exit}\")
  echo \"ENV_PATH=\$ENV_PATH\"
  sudo grep -nE \"^OPENAI_API_(BASE_URL|KEY)=\" \"\$ENV_PATH\" || true
" ' | tee "$EVID/81_openwebui_env_verify.txt"

# 8.3 (Optional) Tail logs briefly; look for outbound calls to /v1 on hx-api-server
ssh hx-webui-server.dev-test.hana-x.ai \
  "sudo journalctl -u open-webui -n 80 --no-pager" \
  | tee "$EVID/82_openwebui_recent_logs.txt"

# Task 9 — Prove an OpenAI-compatible client works (control node test)
echo -e "\n### Task 9: Verifying OpenAI-Compatible Client ###"

# 9A) One-liner curl (models + chat)
# Validate API key from environment
if [ -z "${LITELLM_API_KEY}" ]; then
    echo "ERROR: LITELLM_API_KEY environment variable is not set" >&2
    echo "Please set it with: export LITELLM_API_KEY='your-actual-api-key'" >&2
    exit 1
fi

# Check for placeholder value
if [ "${LITELLM_API_KEY}" = "sk-1234567890abcdef-test-key-please-replace" ]; then
    echo "ERROR: LITELLM_API_KEY contains the placeholder value" >&2
    echo "Please replace it with a valid API key" >&2
    exit 1
fi

# Validate API key format
if [[ ! "${LITELLM_API_KEY}" =~ ^sk-[a-zA-Z0-9]{32,}$ ]]; then
    echo "ERROR: LITELLM_API_KEY has invalid format" >&2
    echo "Expected format: sk-<alphanumeric characters> (minimum 32 chars after 'sk-')" >&2
    echo "Current value length: ${#LITELLM_API_KEY}" >&2
    if [[ ! "${LITELLM_API_KEY}" =~ ^sk- ]]; then
        echo "Key does not start with 'sk-' prefix" >&2
    fi
    exit 1
fi

echo "API key validation passed"

# List models via the gateway
echo -e "\n9A.1) Listing models via gateway:"
curl -fsS -H "Authorization: Bearer ${LITELLM_API_KEY}" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models | jq .

# Minimal chat completion via the gateway
echo -e "\n9A.2) Chat completion test:"
curl -fsS -X POST http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions \
  -H "Authorization: Bearer ${LITELLM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "phi3-3.8b",
        "messages": [{"role":"user","content":"Say hello in one short sentence."}],
        "temperature": 0.7,
        "max_tokens": 50
      }' | jq .

# 9B) Python client (OpenAI-compatible) — full script + run
echo -e "\n9B) Python OpenAI SDK test:"

# Create an isolated venv for the client test
python3 -m venv ~/litellm-client-venv
~/litellm-client-venv/bin/pip install --upgrade pip
~/litellm-client-venv/bin/pip install "openai>=1.40.0"

# Write the test script
cat > ~/litellm_client_test.py <<'PY'
from openai import OpenAI
import os, json

base_url = "http://hx-api-server.dev-test.hana-x.ai:4000/v1"
api_key  = os.environ.get("LITELLM_API_KEY", "").strip()
assert api_key, "LITELLM_API_KEY not set"

client = OpenAI(base_url=base_url, api_key=api_key)

# List models
models = client.models.list()
print("Models:", [m.id for m in models.data])

# Chat completion
resp = client.chat.completions.create(
    model="phi3-3.8b",
    messages=[{"role": "user", "content": "Say hello in one short sentence."}],
    temperature=0.7,
    max_tokens=50,
)
print("Chat:", json.dumps(resp.model_dump(), indent=2))
PY

# Run the script
export LITELLM_API_KEY="sk-1234567890abcdef-test-key-please-replace"
~/litellm-client-venv/bin/python ~/litellm_client_test.py

echo -e "\n================================================"
echo "Integration Complete!"
echo "Open WebUI is now configured to use LiteLLM gateway"
echo "Backup saved at: ${OPENWEBUI_ENV_BACKUP_PATH}"
echo "================================================"

# Disable all traps on successful completion
trap - ERR EXIT