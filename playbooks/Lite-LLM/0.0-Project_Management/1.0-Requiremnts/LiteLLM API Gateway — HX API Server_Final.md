# LiteLLM API Gateway — HX API Server (v1.1 Final)

**Scope:** Stand up LiteLLM proxy on **hx-api-server** to broker Open WebUI → (LiteLLM) → Ollama backends (hx-llm01/02), no Docker. Folded in: **Pre‑Flight Planning (Phases 1–2)**, **Quick triage**, Ops & Eng redlines.

**Authoritative hosts:**
- **LiteLLM** (proxy/gateway): `hx-api-server.dev-test.hana-x.ai` (192.168.10.5) → `:4000`
- **Ollama backends:** `hx-llm01-server.dev-test.hana-x.ai:11434`, `hx-llm02-server.dev-test.hana-x.ai:11434`
- **Open WebUI:** `hx-webui-server.dev-test.hana-x.ai:8080`

**Contract:** OpenAI-style `/v1/*` at `http://hx-api-server.dev-test.hana-x.ai:4000/v1` with a **master key** (LiteLLM virtual key), and model aliases mapping to Ollama models.

---

## 0) Quick triage — repo hygiene (do first)
- **Quarantine stray vaults** under `~/hx-ansible/_quarantine/`:
  - Move `group_vars/all/vault.yml.bad.*` and `vault.yml.bak.*` out of `group_vars/all/`.
  - Keep a single encrypted `group_vars/all/vault.yml` (≤30 lines) per SOP.
- Confirm **standard skeleton** exists (inventories, group_vars, roles, playbooks, templates). Evidence via `tree -L 3`.

---

## 1) Pre‑Flight Planning (Phases 1–2)

> Goal: Validate determinism and trust on **hx-api-server** before introducing a new service on `:4000`.

**Phase 1 — Read‑only checks (no changes)**
1. **DNS**: `dig A hx-api-server.dev-test.hana-x.ai @192.168.10.2 && dig -x 192.168.10.5 @192.168.10.2`
2. **Netplan posture**: Single authoritative file (e.g., `50-hx-static.yaml`), renderer `networkd`, resolver **DC‑only** (192.168.10.2). Snapshot `netplan status`, `resolvectl status`.
3. **Domain/SSO**: `realm list`, `id agent0`, and `sudo -l -U agent0` show AD‑backed privileges.
4. **CA trust**: HX Root CA present in system store; TLS dress rehearsals to internal services succeed.
5. **Python runtime check**: `python3.11 --version` available on host; if absent, install in Phase 2.

**Go/No‑Go Gate (Phase 1):** If any check fails, remediate (Netplan/Domain/CA SOPs) before Phase 2.

**Phase 2 — Minimal enforced state (deterministic)**
- Ensure **one** netplan file; apply `generate → try → apply` sequence.
- Ensure **agent0** elevation via `%hx-linux-admins` sudoers drop‑in; direct root SSH disabled (standard sshd drop‑in).
- **Install Python 3.11 & pip** for the gateway: `apt-get update && apt-get install -y python3.11-venv python3-pip`.
- Evidence bundle: configs + command transcripts saved under `~/hx-ansible/.evidence/api-preflight/<ts>/`.

## 2) Inventory & Group Vars (authoritative)

**Append to `inventories/dev.ini`:**
```
[litellm]
# LiteLLM API Gateway — HX API Server (Final)

---

## Table of Contents
1. [Overview](#1-overview)
2. [Secrets & Vault](#2-secrets--vault)
3. [New role: roles/hx_litellm_proxy/](#3-new-role-roleshx_litellm_proxy)
    - [3.1 Template — templates/litellm.config.yaml.j2](#31-template--templateslitellmconfigymlj2)
    - [3.2 Template — templates/litellm.env.j2](#32-template--templateslitellmenvj2)
    - [3.3 Tasks — tasks/main.yml](#33-tasks--tasksmainyml)
    - [3.4 Unit & hardening — tasks/systemd.yml](#34-unit--hardening--taskssystemdyml)
4. [Play wrapper & run pattern](#4-play-wrapper--run-pattern)
5. [Open WebUI integration (canary → promote)](#5-open-webui-integration-canary--promote)
6. [Smoke tests & acceptance](#6-smoke-tests--acceptance)
7. [Troubleshooting quick hits](#7-troubleshooting-quick-hits)
8. [Change management & rollback](#8-change-management--rollback)
9. [Appendix — Full file inventory](#9-appendix--full-file-inventory)
10. [Notes on future work (backlog)](#notes-on-future-work-backlog)


[llm]
hx-llm01-server.dev-test.hana-x.ai
hx-llm02-server.dev-test.hana-x.ai
```


**`group_vars/all/main.yml` (non‑secret knobs):**
```yaml
# Bind / base URL
litellm_bind_host: "0.0.0.0"
litellm_bind_port: 4000
litellm_base_url: "http://hx-api-server.dev-test.hana-x.ai:4000"

# Ollama backends (hostnames preferred over IPs)
litellm_backends:

  - "http://hx-llm01-server.dev-test.hana-x.ai:11434"
  - "http://hx-llm02-server.dev-test.hana-x.ai:11434"

# Model alias map → Ollama models
litellm_models:
  - name: "phi3-3.8b"
    provider: "ollama"
    model: "phi3:3.8b-mini-128k-instruct-q8_0"
  - name: "llama3-8b"
    provider: "ollama"
    model: "llama3:8b-instruct-q8_0"
```

**`group_vars/all/vault.yml` (encrypted):**
```yaml
# LiteLLM master key for virtual key auth (single ‘master’ used to mint client keys)
litellm_master_key: "sk-REDACT_LOCAL_MASTER"
```

> Notes:
> - We **do not** put API keys for Ollama (local, no key). Clients authenticate to LiteLLM using **master_key**.
> - Keep vault ≤30 lines; rotate via vault edit + service restart.

---

## 3) New role: `roles/hx_litellm_proxy/`

**Layout**
```
roles/hx_litellm_proxy/
├─ tasks/
│  ├─ main.yml
│  └─ systemd.yml
├─ templates/
│  ├─ litellm.config.yaml.j2
│  └─ litellm.env.j2   # (minimal; only non-secret operational knobs if any)
```

### 3.1 Template — `templates/litellm.config.yaml.j2`
> Implements **per-backend duplication** (docs-recommended) with **no per-model api_key**, and **global routing**. Local Ollama needs no key; use empty string to avoid warnings. Global `routing_strategy: least-busy`.
```yaml
# LiteLLM proxy — OpenAI-compatible (duplication approach)
# Each model is duplicated across backends via per-entry api_base.

model_list:
{% for m in litellm_models %}
{%   for b in litellm_backends %}
  - model_name: {{ m.name | quote }}
    litellm_params:
      model: {{ m.model | quote }}
      api_base: {{ b | quote }}
      api_key: ""
      request_timeout: 30
      mode: "chat"
    max_input_tokens: 2048
    num_retries: 2
{%   endfor %}
{% endfor %}


router_settings:
  timeout: 60
  retry_policy: "simple"
  routing_strategy: "least-busy"

general_settings:
  master_key: {{ litellm_master_key | quote }}
  telemetry: false
  # key_management_settings: {}  # reserved for future rotation policies
```

> Redlines folded:
> - **No** `api_key` per-model for Ollama (local); use empty/omit.
> - Use `routing_strategy: least-busy` for dynamic RPM/TPM awareness.
> - Add `request_timeout: 30` per model; dropped `tpm: 0` (unlimited by default).
> - Prefer global `server_settings.ollama.hosts` for backend pool.

```dotenv
# No secrets/keys; auth is in config.yaml (general_settings.master_key)
LITELLM_HOST={{ litellm_bind_host }}
LITELLM_PORT={{ litellm_bind_port }}
# Optional local telemetry toggle for file/STDOUT logs
LITELLM_TELEMETRY=false
```dotenv
# Reserved for non-secret runtime toggles (kept minimal).
# Most auth/settings live in config.yaml (master_key, routing, etc.).
LITELLM_HOST={{ litellm_bind_host }}
LITELLM_PORT={{ litellm_bind_port }}
```

### 3.3 Tasks — `tasks/main.yml`
> Idempotent install; venv under **/home/litellm/litellm-venv** (Ops preference); explicit Python 3.11.
```yaml
---

- name: Ensure service user
  user: { name: litellm, shell: /usr/sbin/nologin, create_home: true, home: /home/litellm }
  apt:
    name:
      - python3.11-venv
      - python3-pip
    state: present
    update_cache: true

- name: Create venv
  command: python3.11 -m venv /home/litellm/litellm-venv
  args: { creates: /home/litellm/litellm-venv/bin/activate }

- name: Install/upgrade LiteLLM with proxy extras
  command: /home/litellm/litellm-venv/bin/pip install --upgrade "litellm[proxy]"

- name: Config directory
  file: { path: /etc/litellm, state: directory, mode: '0755' }

- name: Render env file (0640)
  template:
    src: litellm.env.j2
    dest: /etc/litellm/litellm.env
    mode: '0640'
    owner: root
    group: root

- name: Render proxy config (0640)
  template:
    src: litellm.config.yaml.j2
    dest: /etc/litellm/config.yaml
    owner: root
    group: root
---
- name: Ensure service user

- name: Install runtime prerequisites
  apt:

    name: [python3.11-venv, python3-pip]



- name: Render proxy config (0640)
  template:
    src: litellm.config.yaml.j2
    dest: /etc/litellm/config.yaml
    mode: '0640'
    owner: root
    group: root
```

### 3.4 Unit & hardening — `tasks/systemd.yml`
```yaml
---
- name: Install systemd unit
  copy:
    dest: /etc/systemd/system/litellm.service
    mode: '0644'
    content: |
      [Unit]
      Description=LiteLLM OpenAI-compatible proxy
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=simple
      User=litellm
      EnvironmentFile=/etc/litellm/litellm.env
      ExecStart=/home/litellm/litellm-venv/bin/litellm --config /etc/litellm/config.yaml --host ${LITELLM_HOST} --port ${LITELLM_PORT}
      Restart=always
      RestartSec=3
      # Hardening
      NoNewPrivileges=true
      ProtectSystem=strict
      ProtectHome=true
      ReadWritePaths=/etc/litellm
      PrivateTmp=true
      UMask=007
      CapabilityBoundingSet=~CAP_SYS_ADMIN CAP_NET_ADMIN CAP_SYS_PTRACE

      [Install]
      WantedBy=multi-user.target
  register: unit

- name: daemon-reload when unit changed
  systemd: { daemon_reload: true }
  when: unit.changed

- name: Enable + start + assert active
  systemd: { name: litellm, state: started, enabled: true }

- name: Verify listening port
  command: bash -lc "ss -ltn | awk '{print $4}' | grep -q ':{{ litellm_bind_port }}$'"
  changed_when: false


---

## 4) Play wrapper & run pattern

**`playbooks/litellm_enforce.yml`**
```yaml
---
- hosts: litellm
  gather_facts: false
  tags: [critical, high]
  roles:
    - hx_litellm_proxy
```

**Execute (dry → real; include both tags on apply):**
```bash
ansible-playbook -i inventories/dev.ini playbooks/litellm_enforce.yml \
  --limit hx-api-server -t critical --check --diff

ansible-playbook -i inventories/dev.ini playbooks/litellm_enforce.yml \
  --limit hx-api-server -t critical,high
```

---

## 5) Open WebUI integration (canary → promote)

1. In Open WebUI, add a new **OpenAI-compatible** provider:
   - **Base URL:** `http://hx-api-server.dev-test.hana-x.ai:4000/v1`
   - **API Key:** the LiteLLM **master key** (from vault)
2. Keep direct Ollama providers as **fallback** during canary.
3. Flip default provider to LiteLLM for a canary group; monitor latency & errors; then promote.

**Client/registry examples (for hx‑api, pipelines, etc.)**
```
HXP_OPENAI_URL=http://hx-api-server.dev-test.hana-x.ai:4000/v1
OPENAI_API_KEY=env:OPENAI_API_KEY   # injected from vault/CI
```

---

## 6) Smoke tests & acceptance

**From control node (read‑only):**
```bash
# List models (unauth and auth path)
curl -fsS http://hx-api-server.dev-test.hana-x.ai:4000/v1/models | jq .
curl -fsS -H "Authorization: Bearer ${LITELLM_MASTER}" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models | jq .

# Minimal chat completion
curl -fsS -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${LITELLM_MASTER}" \
  -d '{"model":"phi3-3.8b","messages":[{"role":"user","content":"ping"}]}' \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions | jq .

# Balancing fan-out sanity: fire 10 short requests
for i in $(seq 1 10); do
  curl -fsS -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${LITELLM_MASTER}" \
    -d '{"model":"phi3-3.8b","messages":[{"role":"user","content":"which backend?"}],"stream":false}' \
    http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions >/dev/null &
  sleep 0.2
done; wait

# While the above runs (or right after), on each backend verify connections from hx-api-server:
#   ssh hx-llm01-server "ss -tn sport = :11434 | grep 192.168.10.5 | wc -l"
#   ssh hx-llm02-server "ss -tn sport = :11434 | grep 192.168.10.5 | wc -l"
# Expect roughly comparable connection counts over multiple runs.
```

**Acceptance (Go/No‑Go):**
- `litellm.service` active; port `:4000` listening on LAN.
- `/v1/models` returns alias list; a small completion succeeds.
- Fan‑out indicates both backends receive connections over multiple runs.
- WebUI canary chats succeed via LiteLLM; fallbacks remain available.
- Evidence bundle saved under `~/hx-ansible/.evidence/litellm/<ts>/`.

## 7) Troubleshooting quick hits

| Symptom | Likely cause | Quick diag | Fix |
|---|---|---|---|
| 401 from `/v1/*` | wrong/empty key | check `general_settings.master_key` | Set/rotate master key; restart service |
| 5xx on first backend only | backend down | `curl` both Ollamas | Routing will skip unhealthy; fix backend |
| High p95 latency | backend saturation | check `/api/version` RTT; GPU load | Reduce concurrency; move heavy models |
| `:4000` not listening | unit/env mismatch | `journalctl -u litellm -n100` | Fix config path; daemon-reload; restart |
| Model not found | Alias mismatch or model absent on Ollama | `/v1/models` vs `litellm_models`; `ssh hx-llm0X 'ollama list'` | Align alias names **and** ensure model pulled on backends; reload |

---

## 8) Change management & rollback

- **Change ticket** includes scope, plan, rollback, validation, evidence paths.
- **Rollback:**
  - Restore `/etc/litellm/config.yaml` from backup; `systemctl daemon-reload && systemctl restart litellm`.
  - Temporarily switch WebUI default back to direct Ollama provider if needed.

---

## 9) Appendix — Full file inventory
- `/etc/litellm/config.yaml` (0640)
- `/etc/litellm/litellm.env` (0640)
- `/etc/systemd/system/litellm.service` (0644)
- `/home/litellm/litellm-venv/` (venv)
- Evidence bundles under `~/hx-ansible/.evidence/litellm/<ts>/`

---

### Notes on future work (backlog)
- LiteLLM releases since Jun 2025 (e.g., v1.74.6 MCP namespacing; v1.74.7 Vector Stores & new providers) don’t change core proxy behavior — gateway plan remains compatible. Track MCP only if we scale gateways.
- Optional: add structured access logs and ship to central logging; toggle via `LITELLM_TELEMETRY` or config.
- Optional: per‑model rate limits and virtual key issuance via LiteLLM key management.

