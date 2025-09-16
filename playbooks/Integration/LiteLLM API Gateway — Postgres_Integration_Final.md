# LiteLLM API Gateway — HX API Server (**v1.3 Final**)

**Scope:** Stand up LiteLLM proxy on **hx-api-server** to broker Open WebUI → (LiteLLM) → Ollama backends (hx-llm01/02), no Docker. Incorporates **Pre‑Flight Planning (Phases 1–2)**, **Quick triage**, Ops & Eng redlines, and **LiteLLM ↔ PostgreSQL key‑management integration**.

**Authoritative hosts:**

- **LiteLLM** (proxy/gateway): `hx-api-server.dev-test.hana-x.ai` (192.168.10.5) → `:4000`
- **Ollama backends:** `hx-llm01-server.dev-test.hana-x.ai:11434`, `hx-llm02-server.dev-test.hana-x.ai:11434`
- **Open WebUI:** `hx-webui-server.dev-test.hana-x.ai:8080`
- **PostgreSQL:** `hx-postgres-server.dev-test.hana-x.ai:5432`

**Contract:** OpenAI-style `/v1/*` at `http://hx-api-server.dev-test.hana-x.ai:4000/v1` with a **master key** and model aliases mapping to Ollama models.

---

## 0) Quick triage — repo hygiene (do first)

- **Quarantine stray vaults** under `~/hx-ansible/_quarantine/`.
- Confirm **standard skeleton** exists (inventories, group_vars, roles, playbooks, templates). Evidence via `tree -L 3`.

---

## 1) Pre‑Flight Planning (Phases 1–2)

> Goal: Validate determinism and trust on **hx-api-server** before introducing a new service on `:4000`.

**Phase 1 — Read‑only checks (no changes)**

1. **DNS**: `dig A hx-api-server.dev-test.hana-x.ai @192.168.10.2 && dig -x 192.168.10.5 @192.168.10.2`
2. **Netplan posture**: Single authoritative file (e.g., `50-hx-static.yaml`), renderer `networkd`, resolver **DC‑only** (192.168.10.2). Snapshot `netplan status`, `resolvectl status`.
3. **Domain/SSO**: `realm list`, `id agent0`, and `sudo -l -U agent0` show AD‑backed privileges.
4. **CA trust**: HX Root CA present in system store; TLS dress rehearsals to internal services succeed.
5. **Python runtime check**: `python3.12 --version` available on host; if absent, install in Phase 2.

**Go/No‑Go Gate (Phase 1):** If any check fails, remediate (Netplan/Domain/CA SOPs) before Phase 2.

**Phase 2 — Minimal enforced state (deterministic)**

- Ensure **one** netplan file; apply `generate → try → apply` sequence.
- Ensure **agent0** elevation via `%hx-linux-admins` sudoers drop‑in; direct root SSH disabled.
- **Install Python 3.12 & pip** for the gateway: `apt-get update && apt-get install -y python3.12-venv python3-pip`.
- Evidence bundle: configs + command transcripts saved under `~/hx-ansible/.evidence/api-preflight/<ts>/`.

---

## 2) Inventory & Group Vars

**Append to `inventories/dev.ini`:**

```
[litellm]
hx-api-server.dev-test.hana-x.ai

[llm]
hx-llm01-server.dev-test.hana-x.ai
hx-llm02-server.dev-test.hana-x.ai

[postgres]
hx-postgres-server.dev-test.hana-x.ai
```

**`group_vars/all/litellm.yml` (non‑secret knobs):**

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

# Database wiring for LiteLLM key management
litellm_db_user: "litellm"
litellm_db_name: "litellm"
litellm_db_host: "hx-postgres-server.dev-test.hana-x.ai"
```

**`group_vars/all/vault.yml` (MUST BE ENCRYPTED):**

⚠️ **SECURITY WARNING**: This file MUST always be encrypted using `ansible-vault`. Never commit or store plaintext secrets!

```bash
# Create encrypted vault file:
ansible-vault create inventories/group_vars/all/vault.yml

# Edit existing vault file:
ansible-vault edit inventories/group_vars/all/vault.yml

# Encrypt an existing plaintext file:
ansible-vault encrypt inventories/group_vars/all/vault.yml
```

**Add to `.gitignore`:**

```
# Prevent accidental commit of unencrypted vaults
**/vault.yml
!**/vault.yml.encrypted
```

**Vault file content (example structure only):**

```yaml
# NEVER store these values in plaintext!
litellm_master_key: "{{ ENCRYPTED_VALUE }}"    # Generate with: openssl rand -hex 32
litellm_pg_password: "{{ ENCRYPTED_VALUE }}"    # Generate with: pwgen -s 32 1
openwebui_pg_password: "{{ ENCRYPTED_VALUE }}"  # Generate with: pwgen -s 32 1
```

**CI/CD Protection**: Add pre-commit hooks or CI checks to scan for unencrypted vault files.

---

## 3) Role: `roles/hx_litellm_proxy/`

**Layout**

```
roles/hx_litellm_proxy/
├─ tasks/
│  ├─ main.yml
│  └─ systemd.yml
├─ templates/
│  ├─ litellm.config.yaml.j2
│  └─ litellm.env.j2
```

### 3.1 Authoritative template — `templates/litellm.config.yaml.j2`

> Implements **per-backend duplication**, **no per-model api_key**, **global routing**, and **database_url** for key management (single source of truth).

```yaml
# LiteLLM proxy — v1.3 Final (OpenAI-compatible)
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
  database_url: "{{ lookup('env', 'DATABASE_URL') | default('postgresql://user:password@host:5432/database', true) }}"
  telemetry: false
```

> **Security Note**: The database URL is now read from the `DATABASE_URL` environment variable instead of embedding the password in the configuration file. The actual database credentials are securely injected via the systemd service unit's `Environment=` directive, keeping sensitive data out of configuration files.

### 3.2 Minimal env — `templates/litellm.env.j2`

```dotenv
# Non-secret runtime toggles only; auth lives in config.yaml
LITELLM_HOST={{ litellm_bind_host }}
LITELLM_PORT={{ litellm_bind_port }}
# Optional: local telemetry flag
LITELLM_TELEMETRY=false
```

### 3.3 Tasks — `tasks/main.yml` (idempotent install; **venv under /opt/litellm**)

```yaml
---
- name: Ensure service user
  user: { name: litellm, shell: /usr/sbin/nologin, create_home: true, home: /home/litellm }

- name: Install runtime prerequisites (Python 3.12 + pip)
  apt:
    name:
      - python3.12-venv
      - python3-pip
    state: present
    update_cache: true

- name: Create venv
  command: python3.12 -m venv /opt/litellm
  args: { creates: /opt/litellm/bin/activate }

- name: Install/upgrade LiteLLM with proxy extras
  command: /opt/litellm/bin/pip install --upgrade "litellm[proxy]"

- name: Install PostgreSQL driver for LiteLLM
  command: /opt/litellm/bin/pip install psycopg2-binary

- name: Config directory
  file: { path: /etc/litellm, state: directory, mode: '0755' }

- name: Render env file (0640)
  template:
    src: litellm.env.j2
    dest: /etc/litellm/litellm.env
    mode: '0640'
    owner: root
    group: litellm

- name: Render proxy config (0640)
  template:
    src: litellm.config.yaml.j2
    dest: /etc/litellm/config.yaml
    mode: '0640'
    owner: root
    group: litellm
  notify: Restart litellm
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
      # Database URL must be set in the systemd service for security
      # Example: Environment="DATABASE_URL=postgresql://litellm:password@hx-postgres-server.dev-test.hana-x.ai:5432/litellm"
      Environment="DATABASE_URL=postgresql://{{ litellm_db_user }}:{{ litellm_pg_password }}@{{ litellm_db_host }}:5432/{{ litellm_db_name }}"
      ExecStart=/opt/litellm/bin/litellm --config /etc/litellm/config.yaml --host ${LITELLM_HOST} --port ${LITELLM_PORT}
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

- name: Restart litellm
  systemd:
    name: litellm
    state: restarted
  listen: Restart litellm
```

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

## 5) PostgreSQL access policy (pg_hba) — application-specific databases

**Update `roles/hx_pg_auth/templates/pg_hba.conf.j2`:**

```conf
# Managed by Ansible (hx_pg_auth)
# Local admin via Unix socket
local   all             postgres                                peer

# Loopback (IPv4/IPv6) — enforce TLS + SCRAM
hostssl all             all             127.0.0.1/32            scram-sha-256
hostssl all             all             ::1/128                 scram-sha-256

# LAN — agent0 via GSSAPI
hostgssenc all          agent0          192.168.10.0/24         gss include_realm=0 krb_realm=DEV-TEST.HANA-X.AI
hostssl    all          agent0          192.168.10.0/24         gss include_realm=0 krb_realm=DEV-TEST.HANA-X.AI

# LAN — hx_app to hx_app_db via SCRAM
hostgssenc hx_app_db    hx_app          192.168.10.0/24         scram-sha-256
hostssl    hx_app_db    hx_app          192.168.10.0/24         scram-sha-256

# LAN — LiteLLM app to its dedicated database via SCRAM
hostssl    litellm      litellm         192.168.10.0/24         scram-sha-256

# LAN — Open WebUI app to its dedicated database via SCRAM
hostssl    openwebui    openwebui       192.168.10.0/24         scram-sha-256

# Hard block for non-TLS
hostnossl all           all             0.0.0.0/0               reject
hostnossl all           all             ::0/0                   reject
```

**Apply policy:**

```bash
ansible-playbook -i inventories/dev.ini playbooks/pg_auth_enforce.yml \
  --limit hx-postgres-server.dev-test.hana-x.ai -t critical,high
```

---

## 6) Automated DB & role provisioning (idempotent)

> Removes manual SQL. Requires `community.postgresql` collection.

**Control‑node prep (once):**

```bash
ansible-galaxy collection install community.postgresql
```

**Playbook snippet (extend `roles/hx_pg_auth` or a new `hx_pg_databases` role and include in `pg_auth_enforce.yml`):**

```yaml
- name: Ensure Python driver on DB host (for Ansible modules)
  apt:
    name: python3-psycopg2
    state: present
  become: true

- name: Ensure PostgreSQL users exist with passwords (from vault)
  become: true
  become_user: postgres
  community.postgresql.postgresql_user:
    name: "{{ item.name }}"
    password: "{{ item.password }}"
  loop:
    - { name: 'litellm',   password: "{{ litellm_pg_password }}" }
    - { name: 'openwebui', password: "{{ openwebui_pg_password }}" }
  no_log: true

- name: Ensure PostgreSQL databases exist with owners
  become: true
  become_user: postgres
  community.postgresql.postgresql_db:
    name: "{{ item.name }}"
    owner: "{{ item.owner }}"
  loop:
    - { name: 'litellm',   owner: 'litellm' }
    - { name: 'openwebui', owner: 'openwebui' }
```

---

## 7) Wire LiteLLM to DB & reload

**Confirm `/etc/litellm/config.yaml` contains:**

- `general_settings.master_key: <from vault>`
- `general_settings.database_url: <reads from DATABASE_URL environment variable>`

**Note**: The database URL is no longer hardcoded in the config. It's securely provided via the systemd service's `Environment=` directive in `/etc/systemd/system/litellm.service`

**Reload service:**

```bash
ssh hx-api-server.dev-test.hana-x.ai "sudo systemctl daemon-reload && sudo systemctl restart litellm && sudo systemctl is-active litellm"
```

---

## 8) Smokes — auth, models, chat, and fan‑out

```bash
# Models (unauth → should 401)
curl -fsS http://hx-api-server.dev-test.hana-x.ai:4000/v1/models || echo "(expected 401)"

# Models (auth)
export LITELLM_MASTER_KEY='<paste-from-vault>'
curl -fsS -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models | jq .

# Generate a virtual key (requires DB)
curl -fsS -X POST 'http://hx-api-server.dev-test.hana-x.ai:4000/key/generate' \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H 'Content-Type: application/json' \
  -d '{"key_alias":"webui-canary","duration":"30d","models":["phi3-3.8b","llama3-8b"],"max_budget":25}' | jq .

# Chat completion (using the new virtual key)
export VIRTUAL_KEY='<copy-from-previous>'
curl -fsS -X POST http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions \
  -H "Authorization: Bearer ${VIRTUAL_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"phi3-3.8b","messages":[{"role":"user","content":"Say hello in one short sentence."}]}' | jq .

# Fan‑out probe for backend balancing
for i in $(seq 1 10); do
  curl -fsS -X POST http://hx-api-server.dev-test.hana-x.ai:4000/v1/chat/completions \
    -H "Authorization: Bearer ${VIRTUAL_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"model":"phi3-3.8b","messages":[{"role":"user","content":"which backend?"}],"stream":false}' >/dev/null &
  sleep 0.2
done; wait
```

**TLS+SCRAM proof (from hx-api-server):**

```bash
ssh hx-api-server.dev-test.hana-x.ai "PGPASSWORD='$(ansible-vault view inventories/group_vars/all/vault.yml | awk -F': ' '/^litellm_pg_password:/{print $2}')' psql \
  'postgresql://litellm@hx-postgres-server.dev-test.hana-x.ai:5432/litellm?sslmode=verify-full&sslrootcert=/usr/local/share/ca-certificates/hx-root-ca.crt' \
  -tAc 'SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();'"
```

---

## 9) Open WebUI integration (canary → promote)

1. In Open WebUI, add a new **OpenAI-compatible** provider:
   - **Base URL:** `http://hx-api-server.dev-test.hana-x.ai:4000/v1`
   - **API Key:** the LiteLLM **virtual key** from §8
2. Keep direct Ollama providers as **fallback** during canary.
3. Flip default provider to LiteLLM for a canary group; monitor latency & errors; then promote.

**Client examples (hx‑api, pipelines):**

```
HXP_OPENAI_URL=http://hx-api-server.dev-test.hana-x.ai:4000/v1
OPENAI_API_KEY=<virtual key>
```

---

## 10) Troubleshooting quick hits

| Symptom                   | Likely cause                             | Quick diag                                                     | Fix                                                               |
| ------------------------- | ---------------------------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------- |
| 401 from `/v1/*`          | wrong/empty key                          | check `general_settings.master_key` / virtual key              | Set/rotate master key; restart service                            |
| 5xx on first backend only | backend down                             | `curl` both Ollamas                                            | Routing will skip unhealthy; fix backend                          |
| High p95 latency          | backend saturation                       | check `/api/version` RTT; GPU load                             | Reduce concurrency; move heavy models                             |
| `:4000` not listening     | unit/env mismatch                        | `journalctl -u litellm -n100`                                  | Fix config path; daemon-reload; restart                           |
| Model not found           | Alias mismatch or model absent on Ollama | `/v1/models` vs `litellm_models`; `ssh hx-llm0X 'ollama list'` | Align aliases **and** ensure model pulled on backends; reload     |

---

## 11) Change management & rollback

- **Change ticket** includes scope, plan, rollback, validation, evidence paths.
- **Rollback:**
  - Restore `/etc/litellm/config.yaml` from backup; `systemctl daemon-reload && systemctl restart litellm`.
  - Temporarily switch WebUI default back to direct Ollama provider if needed.

---

## 12) Appendix — Full file inventory

- `/etc/litellm/config.yaml` (0640)
- `/etc/litellm/litellm.env` (0640)
- `/etc/systemd/system/litellm.service` (0644)
- `/opt/litellm/` (venv)
- Evidence bundles under `~/hx-ansible/.evidence/litellm/<ts>/`

---

### Notes / Backlog

- LiteLLM releases since Jun 2025 (e.g., MCP namespacing; Vector Stores & new providers) don’t change core proxy behavior — gateway plan remains compatible.
- Optional: structured access logs shipped to central logging.
- Optional: per‑model rate limits and virtual key issuance workflows in LiteLLM key management.

