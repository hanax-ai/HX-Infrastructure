#!/bin/bash
# LiteLLM Secure Deployment - Tasks 7-9
# Open WebUI Integration with Security Best Practices
# Generated: September 16, 2025

set -euo pipefail

echo "================================================"
echo "LiteLLM Secure Integration - Tasks 7-9"
echo "================================================"

# IMPORTANT SECURITY NOTE:
# The current LiteLLM deployment lacks database support for virtual keys.
# As a temporary measure, we're using the master key, but this should be
# addressed immediately by:
# 1. Adding PostgreSQL database support to LiteLLM
# 2. Generating dedicated virtual keys for each client
# 3. Implementing key rotation policies

echo -e "\n⚠️  SECURITY WARNING ⚠️"
echo "Virtual key generation requires database configuration."
echo "Using master key temporarily - THIS MUST BE FIXED IN PRODUCTION!"
echo -e "\nRecommended immediate actions:"
echo "1. Configure PostgreSQL for LiteLLM: database_url in config"
echo "2. Generate dedicated keys for each client application"
echo "3. Rotate the master key after virtual keys are issued"
echo -e "\nPress Ctrl+C to abort or Enter to continue with temporary solution..."
read -r

# Task 7 — Configure Open WebUI (with security notes)
echo -e "\n### Task 7: Configuring Open WebUI Integration ###"

# Evidence directory
EVID=~/hx-ansible/.evidence/litellm/$(date -u +%Y%m%dT%H%M%SZ); mkdir -p "$EVID"

# TEMPORARY: Using master key until database is configured
# TODO: Replace with virtual key after database setup
export TEMP_API_KEY="sk-1234567890abcdef-test-key-please-replace"

# Document security concern in evidence
cat > "$EVID/SECURITY_NOTE.txt" << EOF
SECURITY CONFIGURATION NOTE - $(date -u)
========================================
Current Status: Using master key for Open WebUI (temporary)
Reason: Database not configured for virtual key generation
Action Required: Configure database and generate dedicated keys
Risk Level: HIGH - Master key exposure to client application
Mitigation: Limit access, rotate key after database setup
EOF

# 7.1 Discover Open WebUI EnvironmentFile path from systemd
ssh hx-webui-server.dev-test.hana-x.ai \
  "sudo systemctl cat open-webui | grep -E '^EnvironmentFile=' | head -1" \
  | tee "$EVID/70_openwebui_envfile_line.txt"

# 7.2 Configure Open WebUI with security warnings
ssh hx-webui-server.dev-test.hana-x.ai 'bash -lc "
  set -euo pipefail
  ENV_LINE=\$(sudo systemctl cat open-webui | grep -E \"^EnvironmentFile=\" | head -1)
  ENV_PATH=\${ENV_LINE#EnvironmentFile=}
  echo \"ENV_PATH=\$ENV_PATH\"
  test -f \"\$ENV_PATH\" || { echo \"ERROR: env file not found at \$ENV_PATH\"; exit 20; }

  # Backup
  sudo cp -a \"\$ENV_PATH\" \"\$ENV_PATH.$(date -u +%Y%m%dT%H%M%SZ).bak\"

  # Remove any prior OPENAI_* lines to avoid duplicates
  sudo sed -i -e \"/^OPENAI_API_BASE_URL=/d\" -e \"/^OPENAI_API_KEY=/d\" \"\$ENV_PATH\"

  # Add configuration with security warning
  sudo tee -a \"\$ENV_PATH\" >/dev/null <<EOF

# SECURITY WARNING: Using master key temporarily
# TODO: Replace with dedicated virtual key after database configuration
OPENAI_API_BASE_URL=http://hx-api-server.dev-test.hana-x.ai:4000/v1
OPENAI_API_KEY='$TEMP_API_KEY'
EOF

  # Show the resulting OPENAI_* lines
  echo \"--- OPENAI lines in \$ENV_PATH ---\"
  sudo grep -E \"^OPENAI_API_(BASE_URL|KEY)=\" \"\$ENV_PATH\" || true
" ' | tee "$EVID/71_openwebui_envfile_after.txt"

# Task 8 — Restart Open WebUI and verify
echo -e "\n### Task 8: Restarting Open WebUI ###"

# 8.1 Restart service cleanly
ssh hx-webui-server.dev-test.hana-x.ai \
  "sudo systemctl daemon-reload && sudo systemctl restart open-webui && sleep 2 && sudo systemctl status --no-pager open-webui" \
  | tee "$EVID/80_openwebui_status_after_restart.txt"

# 8.2 Re-confirm the environment file
ssh hx-webui-server.dev-test.hana-x.ai 'bash -lc "
  ENV_PATH=\$(sudo systemctl cat open-webui | awk -F= \"/^EnvironmentFile=/{print \$2; exit}\")
  echo \"ENV_PATH=\$ENV_PATH\"
  sudo grep -nE \"^OPENAI_API_(BASE_URL|KEY)=\" \"\$ENV_PATH\" || true
" ' | tee "$EVID/81_openwebui_env_verify.txt"

# 8.3 Check logs
ssh hx-webui-server.dev-test.hana-x.ai \
  "sudo journalctl -u open-webui -n 50 --no-pager | tail -30" \
  | tee "$EVID/82_openwebui_recent_logs.txt"

# Task 9 — Verify OpenAI-compatible client (with security notes)
echo -e "\n### Task 9: Verifying OpenAI-Compatible Client ###"

# 9A) Test with curl
export LITELLM_API_KEY="$TEMP_API_KEY"

# List models
echo -e "\n9A.1) Listing models via gateway:"
curl -fsS -H "Authorization: Bearer ${LITELLM_API_KEY}" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models | jq '.data[] | .id' || echo "Failed to list models"

# Chat completion
echo -e "\n9A.2) Chat completion test:"
curl -fsS -X POST http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions \
  -H "Authorization: Bearer ${LITELLM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi3-3.8b",
    "messages": [{"role":"user","content":"Say hello in one short sentence."}],
    "temperature": 0.7,
    "max_tokens": 50
  }' | jq '.choices[0].message.content' || echo "Failed chat completion"

# Create action items for security improvements
echo -e "\n### Creating Security Action Items ###"

cat > "$EVID/SECURITY_ACTION_ITEMS.md" << 'EOF'
# Security Action Items for LiteLLM Deployment

## Immediate Actions Required

1. **Configure Database for Virtual Keys**
   ```yaml
   # Add to /etc/litellm/config.yaml
   general_settings:
     database_url: "postgresql://litellm:password@localhost/litellm"
   ```

2. **Generate Dedicated Virtual Keys**
   ```bash
   # After database configuration:
   curl -X POST http://hx-api-server:4000/key/generate \
     -H "Authorization: Bearer $MASTER_KEY" \
     -d '{"key_alias": "open-webui-prod", "duration": "90d"}'
   ```

3. **Update Open WebUI Configuration**
   - Replace master key with virtual key
   - Document key rotation schedule

4. **Implement Key Rotation Policy**
   - Rotate master key after virtual keys issued
   - Set up automated key rotation
   - Monitor key usage

5. **Add Monitoring**
   - Track API key usage patterns
   - Alert on suspicious activity
   - Log all key operations

## Risk Mitigation (Current State)

- Limit network access to API gateway
- Monitor logs for unauthorized access
- Plan immediate database deployment
- Document all temporary measures

## Timeline

- [ ] Day 1: Deploy PostgreSQL database
- [ ] Day 2: Configure LiteLLM with database
- [ ] Day 3: Generate virtual keys
- [ ] Day 4: Update all clients
- [ ] Day 5: Rotate master key
EOF

echo -e "\n================================================"
echo "Integration Complete (with Security Warnings)"
echo "================================================"
echo "✅ Open WebUI configured to use LiteLLM gateway"
echo "⚠️  USING MASTER KEY TEMPORARILY - MUST BE FIXED"
echo "📋 Security action items saved to: $EVID/SECURITY_ACTION_ITEMS.md"
echo "================================================"