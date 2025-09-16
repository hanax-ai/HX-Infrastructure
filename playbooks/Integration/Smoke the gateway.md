# Unauth should fail (401)
curl -s http://hx-api-server.dev-test.hana-x.ai:4000/v1/models || echo "(expected unauthorized)"

# Auth with master key (replace with your real value if not templated yet)
export LITELLM_MASTER_KEY="$(ssh hx-api-server.dev-test.hana-x.ai \
  "sudo grep '^[[:space:]]*master_key:' /etc/litellm/config.yaml | cut -d':' -f2- | tr -d '\"'\'' ' | xargs echo")"

if [[ -z "$LITELLM_MASTER_KEY" ]]; then
  echo "ERROR: Failed to extract master key"
  exit 1
fi

curl -fsS -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models | jq .

# (If database_url is configured) generate a virtual key
curl -fsS -X POST 'http://hx-api-server.dev-test.hana-x.ai:4000/key/generate' \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{"key_alias":"canary","duration":"7d","models":["phi3-3.8b","llama3-8b"],"max_budget":10}' | jq .
