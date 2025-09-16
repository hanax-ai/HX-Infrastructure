# HX Platform — PostgreSQL & Redis Authentication SOP + Runbook (v1.0f)

*(Expands SOP-PG-AUTH-01 & SOP-REDIS-APP-01)*

**Audience:** Senior SREs & platform engineers  
**Env:** Ubuntu 24.04 LTS, realm `DEV-TEST.HANA-X.AI`, HX Root CA deployed, Ansible repo at `~/hx-ansible`  
**Primary hosts:**

- **DB:** `hx-postgres-server` (PostgreSQL 17 + Redis 7)  
- **DevOps:** `hx-devops-server` (Ansible control node)  
- **DC:** `hx-dc-server` (Samba AD DC / Kerberos KDC)

> **Note on length:** This is a single-file, end-to-end SOP & runbook covering all requested sections—including build, auth models (TLS/SCRAM/GSSAPI), Redis hardening, Ansible role docs, runbooks, verification, troubleshooting, and appendices. If you want any section expanded further, say **“Expand §<number>”**.

---

## 1) Executive Summary & Scope

**Objective.** Deliver a secure, repeatable, and audited pattern for database & cache connectivity at HX that:

- Enforces TLS transport for PostgreSQL & Redis.  
- Uses SCRAM-SHA-256 for app credentials to PostgreSQL.  
- Enables Kerberos/GSSAPI SSO for privileged operators (e.g., `agent0`).  
- Hardens Redis with AOF persistence, systemd sandboxing, and precise write path allowlists.  
- Encapsulates the policy in Ansible for idempotent enforcement and re-runs.

**Why this matters.** This SOP reduces auth drift, prevents plaintext/data-in-transit exposure, and sets a baseline for compliance artifacts (evidence bundles, acceptance tests, and rollback).

**Success criteria.**

- `psql \conninfo` succeeds over GSS for `agent0` and over TLS+SCRAM for `hx_app`.  
- `pg_hba.conf` parses with 0 errors; `password_encryption` is `scram-sha-256`.  
- Redis accepts `AUTH` (AOF enabled), survives a restart, and writes in `/redispersist/appendonlydir`.  
- The Ansible role `hx_pg_auth` applies cleanly with `--check/--diff` and with vault-provided secrets.

**Out of scope.** Database schema design, application-level pool tuning, change data capture, and cross-region DR.

---

## 2) Reference Architecture

### 2.1 ASCII topology
```
+----------------------+           +------------------+
|  hx-devops-server    |           |  hx-dc-server    |
|  (Ansible control)   |           |  Samba AD + KDC  |
|                      |  Kerberos |  (realm DEV-TEST)|
|  vault.yml (PG pwd)  <---------->+   Issues TGT/TGS |
+------------+---------+           +--------+---------+
             |                               ^
             | Ansible SSH                   |
             v                               | kadmin/samba-tool
+------------+-------------------------------------------+
|                hx-postgres-server                      |
|  PostgreSQL 17 (TLS + SCRAM + GSSAPI)                  |
|   - Data:   /pgdata/pg17                               |
|   - WAL:    /pgwal/pg_wal                              |
|   - HBA:    /etc/postgresql/17/main/pg_hba.conf        |
|   - Keytab: /etc/postgresql/17/main/postgres.keytab    |
|  Redis 7 (AOF, sandbox)                                 |
|   - Persist: /redispersist/appendonlydir               |
+--------------------------------------------------------+
             ^                         ^
             | TLS / GSS               | TLS / AUTH
             |                         |
   +---------+---------+     +---------+---------+
   | hx-api-server     |     | hx-orchestrator  |
   | (app clients)     |     | (app clients)    |
   +-------------------+     +------------------+
```

### 2.2 Mermaid (PG/Redis auth/dataflow)
```
flowchart LR
  subgraph Clients
    API[hx-api-server]
    ORCH[hx-orchestrator-server]
    AGENT[agent0 (SRE)]
  end

  subgraph Infra
    DC[hx-dc-server (KDC)]
    DEVOPS[hx-devops-server (Ansible)]
  end

  subgraph DB["hx-postgres-server"]
    PG[(PostgreSQL 17)]
    REDIS[(Redis 7)]
  end

  AGENT -- GSS TGT/TGS --> DC
  AGENT -- GSS psql TLS --> PG
  API -- TLS+SCRAM psql --> PG
  ORCH -- TLS+SCRAM psql --> PG
  API -- AUTH redis-cli --> REDIS
  ORCH -- AUTH redis-cli --> REDIS

  DEVOPS -- SSH+Ansible --> PG
  DEVOPS -- SSH+Ansible --> REDIS
  DEVOPS -- Kerb admin --> DC
```

---

## 3) Threat Model & Security Controls

### Redis Hardening (Optional)

**Note:** Redis hardening is optional and staged, disabled by default to ensure compatibility. Before enabling these security measures, thoroughly test in a non-production environment and document both the impact and rollback procedures.

**Recommended security settings:**

- **Protected Mode:** Keep `protected-mode yes` to prevent external access without authentication
- **Network Binding:** Bind only to required addresses (e.g., `127.0.0.1 192.168.10.10`) to limit network exposure
- **Command Renaming:** Optionally rename dangerous commands like `rename-command CONFIG "CONFIG_DISABLED"` to prevent configuration changes
  
**Important:** Document the impact of each security measure and maintain a rollback plan before enabling in production environments.

## 4) Detailed Build Procedures

Commands are labeled per-host as **[DB]**, **[DC]**, **[DevOps]**, **[App]**. Copy-paste blocks as-is.

### 4.1 Packages & systemd hardening (summary)

**[DB] PostgreSQL & Redis install (Ubuntu 24.04)**
```
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl ca-certificates

# PGDG repo
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
  --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
. /etc/os-release
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
https://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main" \
| sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt update

# PostgreSQL 17 & Redis
sudo apt install -y postgresql-17 postgresql-client-17 postgresql-doc-17 libpq-dev postgresql-server-dev-17
sudo apt install -y redis-server

# Stop & disable until hardened
sudo systemctl stop postgresql redis-server
sudo systemctl disable postgresql redis-server
```

**Systemd umask hardening**
```
# PostgreSQL template unit uses postgresql@.service
sudo mkdir -p /etc/systemd/system/postgresql@.service.d
cat <<'EOF' | sudo tee /etc/systemd/system/postgresql@.service.d/override.conf
[Service]
UMask=0077
EOF

# Redis unit is redis-server.service
sudo mkdir -p /etc/systemd/system/redis-server.service.d
cat <<'EOF' | sudo tee /etc/systemd/system/redis-server.service.d/override.conf
[Service]
UMask=0077
EOF

sudo systemctl daemon-reload
```

**Acceptance check**
```
systemctl show postgresql@17-main | grep -i UMask
systemctl show redis-server | grep -i UMask
# Expect UMask=0077
```

### 4.2 PostgreSQL bootstrap (data paths, TLS, HBA)

**Paths**

- Data: `/pgdata/pg17`
- WAL: `/pgwal/pg_wal`
- Archive (later): `/pgarchive/wal`
- Config dir: `/etc/postgresql/17/main`

**[DB] Initialize cluster**
```
sudo mkdir -p /pgdata/pg17 /pgwal/pg_wal
sudo chown -R postgres:postgres /pgdata /pgwal
sudo chmod 0700 /pgdata/pg17 /pgwal/pg_wal

sudo -u postgres /usr/lib/postgresql/17/bin/initdb -D /pgdata/pg17 --waldir=/pgwal/pg_wal
```

**[DB] TLS material**  
*(Server key, CSR, signed by HX CA; cert placed at `/etc/ssl/postgresql/server.crt`, key at `/etc/ssl/postgresql/server.key` with `0640` `root:postgres`.)*

**[DB] Core `postgresql.conf` deltas**
```
sudo tee -a /etc/postgresql/17/main/postgresql.conf >/dev/null <<'EOF'
listen_addresses = '*'
password_encryption = 'scram-sha-256'
ssl = on
ssl_cert_file = '/etc/ssl/postgresql/server.crt'
ssl_key_file = '/etc/ssl/postgresql/server.key'
# Optional: WAL arch hooks (Task 14)
# wal_level = replica
# archive_mode = on
# archive_command = 'test ! -f /pgarchive/wal/%f && cp %p /pgarchive/wal/%f'
EOF
```

**[DB] `pg_hba.conf` (final model)**  
GSS for `agent0`; SCRAM for `hx_app`; TLS enforced; non-TLS rejected.
```
sudo tee /etc/postgresql/17/main/pg_hba.conf >/dev/null <<'EOF'
# Local admin via Unix socket
local   all             postgres                                peer

# Loopback (IPv4/IPv6) — enforce TLS + SCRAM
hostssl all             all             127.0.0.1/32            scram-sha-256
hostssl all             all             ::1/128                 scram-sha-256

# LAN — agent0 via GSSAPI (GSS-encrypted and TLS transports)
hostgssenc all          agent0          192.168.10.0/24         gss include_realm=0 krb_realm=DEV-TEST.HANA-X.AI
hostssl   all           agent0          192.168.10.0/24         gss include_realm=0 krb_realm=DEV-TEST.HANA-X.AI

# LAN — hx_app to hx_app_db via SCRAM (both transports)
hostgssenc hx_app_db    hx_app          192.168.10.0/24         scram-sha-256
hostssl   hx_app_db     hx_app          192.168.10.0/24         scram-sha-256

# Hard block for non-TLS anywhere (belt & suspenders)
hostnossl all           all             0.0.0.0/0               reject
hostnossl all           all             ::0/0                   reject
EOF
```

**[DB] Start PostgreSQL cluster**
```
sudo systemctl enable postgresql@17-main
sudo systemctl start postgresql@17-main
```

**Acceptance checks**
```
sudo -u postgres psql -tAc "SHOW hba_file;"
sudo -u postgres psql -c "SELECT type,database,user_name,address,auth_method,error FROM pg_hba_file_rules WHERE error IS NOT NULL;"
sudo -u postgres psql -tAc "SHOW password_encryption;"
# Expect: no HBA errors; scram-sha-256
```

### 4.3 Kerberos/GSSAPI (SPN, keytab, server binding)

**Facts**

- SPN: `postgres/hx-postgres-server.dev-test.hana-x.ai`  
- Keytab on DB: `/etc/postgresql/17/main/postgres.keytab`  
- Postgres binding: `krb_server_keyfile = '/etc/postgresql/17/main/postgres.keytab'` (in `postgresql.conf`)

**[DC] Put SPN on the truncated machine account & export keytab**
```
sudo -i
kinit agent0
SPN='postgres/hx-postgres-server.dev-test.hana-x.ai'
# Find truncated sAMAccountName (e.g. HX-POSTGRES-SER$)
samba-tool computer list | grep -i '^hx-postgres'
CORRECT='HX-POSTGRES-SER$'   # set to actual

# Ensure SPN is on the correct object
samba-tool spn add "$SPN" "$CORRECT" || true
samba-tool spn list "$CORRECT" | grep -F "$SPN"

# Export keytab containing only this SPN
umask 077
samba-tool domain exportkeytab /var/tmp/postgres.keytab \
  --principal="${SPN}@DEV-TEST.HANA-X.AI"
klist -k /var/tmp/postgres.keytab | grep -F "$SPN"
```

**[DC] Copy keytab to DB host**
```
scp /var/tmp/postgres.keytab agent0@hx-postgres-server.dev-test.hana-x.ai:/tmp/postgres.keytab
```

**[DB] Install keytab and bind Postgres**
```
sudo install -o postgres -g postgres -m 0600 /tmp/postgres.keytab /etc/postgresql/17/main/postgres.keytab
# Hygiene: ensure strict ownership/permissions
sudo chown postgres:postgres /etc/postgresql/17/main/postgres.keytab
sudo chmod 600 /etc/postgresql/17/main/postgres.keytab
sudo grep -q '^krb_server_keyfile' /etc/postgresql/17/main/postgresql.conf \
 || echo "krb_server_keyfile = '/etc/postgresql/17/main/postgres.keytab'" \
    | sudo tee -a /etc/postgresql/17/main/postgresql.conf
sudo systemctl restart postgresql@17-main
sudo -u postgres klist -k /etc/postgresql/17/main/postgres.keytab | grep -i postgres
```

**Acceptance checks**
```
# [DC] Prove KDC issues ticket for this SPN
kinit agent0
kvno postgres/hx-postgres-server.dev-test.hana-x.ai@DEV-TEST.HANA-X.AI

# [Client/DevOps] GSS connection
. /etc/hx/connection_env
kinit agent0
psql "${HXP_PG_URL_GSS} user=agent0 sslrootcert=${HXP_PG_CA}" -v VERBOSITY=terse -c '\conninfo'
# Expect "GSSAPI-encrypted connection" or TLS with GSS auth.
```

### 4.4 Redis hardening (persistence & sandbox)

**Paths**

- Persistence root: `/redispersist`  
- Multi-AOF subdir: `/redispersist/appendonlydir`

**[DB] Redis config (journald logging, AOF, bind strict)**
```
sudo mkdir -p /redispersist/appendonlydir
sudo chown -R redis:redis /redispersist
sudo chmod 0750 /redispersist /redispersist/appendonlydir

sudo tee /etc/redis/redis.conf >/dev/null <<'EOF'
bind 127.0.0.1 192.168.10.10
port 6379
protected-mode yes
requirepass ${REDIS_PASSWORD_NOT_STORED_HERE}
appendonly yes
dir /redispersist
appenddirname "appendonlydir"
logfile ""
EOF
```

**[DB] Allowlist write paths (systemd drop-in)**
```
sudo mkdir -p /etc/systemd/system/redis-server.service.d
sudo tee /etc/systemd/system/redis-server.service.d/override.conf >/dev/null <<'EOF'
[Service]
# Keep stock writable paths AND add ours explicitly
ReadWritePaths=/var/lib/redis
ReadWritePaths=/var/log/redis
ReadWritePaths=/redispersist
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now redis-server
```

**Acceptance checks**
```
systemctl status redis-server --no-pager
ss -tuln | grep ':6379'
# From peer:
REDISCLI_AUTH='<runtime-secret>' redis-cli -h hx-postgres-server.dev-test.hana-x.ai -p 6379 PING
# Expect PONG. After writes:
ls -l /redispersist/appendonlydir
```

---

## 5) Ansible Role Docset (`hx_pg_auth`)

### 5.1 Role overview$1**Shell guidance (bash vs sh).** Prefer `command:` unless a shell is required. If you use `shell:`, pin `executable: /bin/bash` to avoid `/bin/sh` pitfalls (e.g., `set -o pipefail`).

```yaml
# When you truly need a shell, pin bash to avoid /bin/sh quirks.
- name: example using bash
  shell: |
    set -Eeuo pipefail
    some_pipeline | awk '{print $1}'
  args:
    executable: /bin/bash
```

### 5.2 Variables (defaults)

> **Env segmentation tip:** Override `hx_pg_subnet` in `group_vars` per environment (prod/staging) to avoid relying on the default `192.168.10.0/24`.
>
> ```yaml
> # inventories/group_vars/prod.yml
> hx_pg_subnet: 10.20.0.0/16
> ```

`roles/hx_pg_auth/defaults/main.yml` (no secrets):
```
hx_pg_cluster_version: 17
hx_pg_cluster_name: main

hx_pg_db: hx_app_db
hx_pg_app_user: hx_app
hx_pg_gss_user: agent0
hx_pg_subnet: 192.168.10.0/24
hx_pg_realm: DEV-TEST.HANA-X.AI

hx_pg_ca_path: /usr/local/share/ca-certificates/hx-root-ca.crt
hx_pg_conf_dir: "/etc/postgresql/{{ hx_pg_cluster_version }}/{{ hx_pg_cluster_name }}"
hx_pg_hba_path: "{{ hx_pg_conf_dir }}/pg_hba.conf"
hx_pg_conf_path: "{{ hx_pg_conf_dir }}/postgresql.conf"
hx_pg_keytab_path: "{{ hx_pg_conf_dir }}/postgres.keytab"

hx_pg_hardening_reject_nossl: true
hx_pg_enforce_tls_floor: true

hx_pg_app_password: ""     # supply via vault

hx_pg_backup_dir: /var/backups/hx/pg
hx_pg_backup_ts: "{{ ansible_date_time.date }}-{{ ansible_date_time.hour }}{{ ansible_date_time.minute }}{{ ansible_date_time.second }}"
```

**Vault integration**  
`inventories/group_vars/all/vault.yml` (encrypted with ansible-vault):
```
hx_pg_app_password: "STRONG_SECRET"
```

### 5.3 Template

`roles/hx_pg_auth/templates/pg_hba.conf.j2` (rendered variant used in prod)
```
# Managed by Ansible (hx_pg_auth)
local   all             postgres                                peer
hostssl all             all             127.0.0.1/32            scram-sha-256
hostssl all             all             ::1/128                 scram-sha-256

hostgssenc all          {{ hx_pg_gss_user }}   {{ hx_pg_subnet }}   gss include_realm=0 krb_realm={{ hx_pg_realm }}
hostssl   all           {{ hx_pg_gss_user }}   {{ hx_pg_subnet }}   gss include_realm=0 krb_realm={{ hx_pg_realm }}

hostgssenc {{ hx_pg_db }} {{ hx_pg_app_user }} {{ hx_pg_subnet }}   scram-sha-256
hostssl   {{ hx_pg_db }} {{ hx_pg_app_user }} {{ hx_pg_subnet }}    scram-sha-256

{% if hx_pg_hardening_reject_nossl %}
hostnossl all all 0.0.0.0/0 reject
hostnossl all all ::0/0    reject
{% endif %}
```

### 5.4 Tasks (high-level)

- **tasks/backup.yml:** Create `/var/backups/hx/pg`; copy `pg_hba.conf` & `postgresql.conf` with timestamp.  
- **tasks/main.yml (key excerpts):**
  - Template `pg_hba.conf`.  
  - Line-edit `postgresql.conf` for SSL & SCRAM (and TLS floor).  
  - Flush handlers (reload PG).  
  - Validate HBA parse: `SELECT COUNT(*) FROM pg_hba_file_rules WHERE error IS NOT NULL;`  
  - **Password flow** (if `hx_pg_app_password` set):
    - Test login with provided secret (TLS; `gssencmode=disable`).
    - If it fails: set password with a `psql -v` variable to avoid quoting issues.
    - Re-test login; assert success.

**Pre-flight guard (cluster presence)**

```yaml
- name: Assert PG cluster directory exists
  stat:
    path: "{{ hx_pg_conf_dir }}"
  register: pgdir
- name: Fail fast if cluster missing
  fail:
    msg: "PostgreSQL cluster not found at {{ hx_pg_conf_dir }}. Initialize or correct hx_pg_cluster_* vars."
  when: not pgdir.stat.exists
```

### 5.5 How to run

**Dry-run with diff**
```
ansible-playbook playbooks/pg_auth_enforce.yml --check --diff \
  --limit hx-postgres-server.dev-test.hana-x.ai --ask-vault-pass
```

**Apply**
```
ansible-playbook playbooks/pg_auth_enforce.yml \
  --limit hx-postgres-server.dev-test.hana-x.ai --ask-vault-pass
```

**Smoke (PG + GSS + SCRAM)**
```
ansible-playbook playbooks/smoke_pg.yml --ask-vault-pass
```

**Limits & notes**

- Role expects PG cluster present at `/etc/postgresql/17/main` and HX Root CA already deployed.  
- **No secrets** are written to `/etc/hx/connection_env`; inject via environment/vault at runtime.

---

## 6) Ops Runbooks

### 6.1 Day-0 (initialization)

- Install & stop services: §4.1  
- Init PG data/WAL; TLS material: §4.2  
- Apply HBA policy; enable SCRAM; start PG  
- Create SPN/keytab; bind Postgres: §4.3  
- Redis config & sandbox: §4.4  
- Ansible enforce + smoke: §5.5, `smoke_pg.yml`

**Acceptance gate (Go/No-Go):**  
`psql \conninfo` works for both GSS and SCRAM; `redis-cli PING` returns `PONG`.

### 6.2 Day-1 (post-install)

- **Backups/DR hooks:**  
  - PG: set `wal_level=replica`, `archive_mode=on`, `archive_command` to `/pgarchive/wal`; schedule `pg_basebackup` if required.  
  - Redis: confirm AOF rolling files present in `/redispersist/appendonlydir`.
- **Artifact bundle** (see §10).

### 6.3 Day-2 (ongoing)

- **Password rotation (PG app):**  
  Update `inventories/group_vars/all/vault.yml` with new secret via `ansible-vault edit`.  
  Re-run `pg_auth_enforce.yml`; the role will set and verify.  
- **SPN/keytab rotation:**  
  Re-export keytab on DC; copy; update file on DB; restart PG.  
- **Periodic smoke (cron/CI):** `smoke_pg.yml`.

---

## 7) Verification & Acceptance Criteria

**PostgreSQL**
```
# Parse sanity
sudo -u postgres psql -tAc "SHOW hba_file;"
sudo -u postgres psql -c "SELECT * FROM pg_hba_file_rules WHERE error IS NOT NULL;"
sudo -u postgres psql -tAc "SHOW password_encryption;"   # scram-sha-256

# GSS SSO path
. /etc/hx/connection_env
kinit agent0@DEV-TEST.HANA-X.AI
psql "${HXP_PG_URL_GSS} user=agent0 sslrootcert=${HXP_PG_CA}" -v VERBOSITY=terse -c '\\conninfo'

# Password fallback path (disable GSS transport preference)
export HXP_APP_DB_PASSWORD='<secret at runtime>'
psql "postgresql://hx_app:${HXP_APP_DB_PASSWORD}@hx-postgres-server.dev-test.hana-x.ai:5432/hx_app_db?sslmode=verify-full&sslrootcert=${HXP_PG_CA}" \
  -v VERBOSITY=terse -c '\\conninfo'
unset HXP_APP_DB_PASSWORD
```

**TLS visibility (live session)**
```
psql "${HXP_PG_URL_GSS} user=agent0" -c '\conninfo'
psql "postgresql://hx_app:*****@hx-postgres-server.dev-test.hana-x.ai:5432/hx_app_db?sslmode=verify-full&sslrootcert=${HXP_PG_CA}" \
  -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
```

**TLS**
```
openssl s_client -connect hx-postgres-server.dev-test.hana-x.ai:5432 \
  -starttls postgres -CAfile /usr/local/share/ca-certificates/hx-root-ca.crt -verify_return_error
```

**Kerberos**
```
kinit agent0
kvno postgres/hx-postgres-server.dev-test.hana-x.ai@DEV-TEST.HANA-X.AI
klist
```

**Redis**
```
REDISCLI_AUTH='<secret>' redis-cli -h hx-postgres-server.dev-test.hana-x.ai -p 6379 PING
redis-cli -h hx-postgres-server.dev-test.hana-x.ai -a '<secret>' INFO persistence | egrep 'aof_enabled|aof_rewrite_in_progress'
ls -l /redispersist/appendonlydir
```

**Acceptance:** All commands succeed; no HBA parse errors; SCRAM in effect; Redis AOF active with writable directory.

---

## 8) Troubleshooting Encyclopedia

| Symptom | Likely cause | Quick diag | Fix |
|---|---|---|---|
| `FATAL: no pg_hba.conf entry …` | Missing/wrong HBA rule order | `SELECT * FROM pg_hba_file_rules` | Ensure specific rules (app user/db) come before broader GSS rules; reload. |
| `could not initiate GSSAPI security context: Server not found` | SPN not on correct (truncated) computer account; wrong keytab | On DC: `samba-tool spn list <acct>`; `kvno` SPN; On DB: `klist -k` | Move SPN to truncated sAMAccountName; re-export keytab; install & restart PG. |
| `Redis … Can't open append-only dir … Read-only file system` | systemd sandbox write path not allowlisted | `journalctl -u redis-server` | Add `ReadWritePaths=/redispersist` drop-in, reload daemon, restart Redis. |
| `psql: root certificate file … does not exist` | Client missing HX CA | Deploy HX Root CA to client or use DSN with `sslrootcert=${HXP_PG_CA}`. |
| `password authentication failed` | Wrong secret or not updated on server | Try `PGPASSWORD='...' psql` locally; check role run | Rotate via Ansible role; verify with `\conninfo`. |
| `/bin/sh: set: Illegal option -o pipefail` | Shell module defaulting to `/bin/sh` | Check task uses `shell:` and uses bash syntax | Avoid `pipefail` in `/bin/sh` or force `/bin/bash` via `executable`. |
| Host key unknown on first scp/ssh | New host fingerprint | Confirm fingerprint; accept once | That’s expected; proceed. |

**GSS “server not found” deep-dive (condensed)**

- Ensure SPN string matches FQDN: `postgres/hx-postgres-server.dev-test.hana-x.ai`  
- Confirm ownership on truncated machine account (e.g., `HX-POSTGRES-SER$`).  
- Export keytab with only this SPN; verify `klist -k`.  
- In `postgresql.conf`, set `krb_server_keyfile` to the keytab path, and restart.

---

## 9) Change Management

**Pre-change checklist**

- [ ] Window approved; stakeholders notified.  
- [ ] Backups: `/var/backups/hx/pg` contains today’s snapshots.  
- [ ] Vault secret tested (`ansible ... debug` length).  
- [ ] Rollback steps printed (below).

**Execution**

- Use `--check --diff` first; then apply once green.  
- Run `smoke_pg.yml` afterward.

**Rollback**

- `pg_hba.conf`: restore from `/var/backups/hx/pg/pg_hba.conf.<ts>`; `SELECT pg_reload_conf();`  
- `postgresql.conf`: restore file; `systemctl restart postgresql@17-main`.  
- Redis: revert drop-ins; daemon-reload; `systemctl restart redis-server`.  
- If auth outage for app: temporarily allow list specific source with time-boxed rule while remediating.

**Risk matrix (abridged)**

| Change | Impact | Likelihood | Mitigation |
|---|---|---|---|
| HBA template change | Connection drop | Med | `--check/--diff`, parse validation, staged roll. |
| Password rotation | App login fails | Low–Med | Coordinated deploy, secret in vault, smoke. |
| SPN/keytab rotate | GSS SSO fails | Med | Keep old keytab until success verified. |
| Redis drop-in edits | Redis restart | Low | Staged restart; confirm AOF after. |

---

## 10) Compliance & Audit

**Artifact bundle (server-side evidence).**
```
[DB]
sudo bash -c '
set -Eeuo pipefail
mkdir -p /tmp/hx-verify
psql -U postgres -tAc "SHOW hba_file;" > /tmp/hx-verify/hba_path.txt
cp /etc/postgresql/17/main/pg_hba.conf /tmp/hx-verify/pg_hba.conf
psql -U postgres -c "SELECT * FROM pg_hba_file_rules WHERE error IS NOT NULL;" > /tmp/hx-verify/hba_errors.txt
psql -U postgres -tAc "SHOW password_encryption;" > /tmp/hx-verify/pwd_enc.txt
openssl x509 -in /etc/ssl/postgresql/server.crt -noout -subject -issuer -dates > /tmp/hx-verify/tls_cert.txt
systemctl status postgresql@17-main --no-pager > /tmp/hx-verify/pg_service.txt
sudo -u postgres klist -k /etc/postgresql/17/main/postgres.keytab > /tmp/hx-verify/pg_keytab.txt
systemctl status redis-server --no-pager > /tmp/hx-verify/redis_service.txt
journalctl -u redis-server -n 50 --no-pager > /tmp/hx-verify/redis_journal_tail.txt
tar czf /tmp/hx-verify.tar.gz -C /tmp hx-verify
echo "Bundle: /tmp/hx-verify.tar.gz"
'
```

**Tagging & commit practice (DevOps):**
```
cd ~/hx-ansible
git status
git add roles/hx_pg_auth playbooks/pg_auth_enforce.yml inventories/group_vars/all/
git commit -m "Enforce PG auth policy; rotate secrets; evidence bundle ready"
git tag -a v1.0-sop-pg-auth-01 -m "Baseline after enforcement and smoke"
```

**Retention note:** Attach the evidence bundle to the change record and retain it per the HX compliance retention policy (e.g., ≥ 1 year).

---

## 11) Appendices

### 11.1 Inventory (from `inventories/dev.ini`)
```
[dev]
hx-dc-server.dev-test.hana-x.ai
hx-ca-server.dev-test.hana-x.ai
hx-api-server.dev-test.hana-x.ai
hx-llm01-server.dev-test.hana-x.ai
hx-llm02-server.dev-test.hana-x.ai
hx-orchestrator-server.dev-test.hana-x.ai
hx-vectordb-server.dev-test.hana-x.ai
hx-postgres-server.dev-test.hana-x.ai
hx-webui-server.dev-test.hana-x.ai
hx-dev-server.dev-test.hana-x.ai
hx-test-server.dev-test.hana-x.ai
hx-devops-server.dev-test.hana-x.ai
hx-docs-server.dev-test.hana-x.ai
hx-metrics-server.dev-test.hana-x.ai
hx-fs-server.dev-test.hana-x.ai
```

### 11.2 Full Ansible artifacts (non-secret)

**`playbooks/pg_auth_enforce.yml`**
```
---
- name: Enforce PostgreSQL auth policy (SOP-PG-AUTH-01)
  hosts: hx-postgres-server.dev-test.hana-x.ai
  gather_facts: true
  become: true
  roles:
    - hx_pg_auth
```

**`roles/hx_pg_auth/defaults/main.yml` — see §5.2**

**`roles/hx_pg_auth/handlers/main.yml`**
```
---
- name: reload pg config
  become: true
  become_user: postgres
  ansible.builtin.command: psql -c "SELECT pg_reload_conf();"
  changed_when: true
```

**`roles/hx_pg_auth/templates/pg_hba.conf.j2` — see §5.3**

**`roles/hx_pg_auth/tasks/backup.yml` — see §5.4 (backup)**

**`roles/hx_pg_auth/tasks/main.yml` (key logic summarized in §5.4; you already committed the working version)**

**`playbooks/smoke_pg.yml`** (non-intrusive smoke for PG/Redis; you have it committed and verified)

### 11.3 `postgresql.conf` (delta recap)
```
listen_addresses = '*'
password_encryption = 'scram-sha-256'
ssl = on
ssl_cert_file = '/etc/ssl/postgresql/server.crt'
ssl_key_file = '/etc/ssl/postgresql/server.key'
# Optional floor
ssl_min_protocol_version = 'TLSv1.2'
# Optional archiving
# wal_level = replica
# archive_mode = on
# archive_command = 'test ! -f /pgarchive/wal/%f && cp %p /pgarchive/wal/%f'
# GSS keytab
krb_server_keyfile = '/etc/postgresql/17/main/postgres.keytab'
```

### 11.4 Glossary

- **SCRAM-SHA-256:** Modern salted+iterated password hashing for PostgreSQL.  
- **GSSAPI:** Generic Security Services API; we use Kerberos for SSO.  
- **SPN:** Service Principal Name—identity for Kerberos service tickets.  
- **Keytab:** File containing Kerberos keys for non-interactive services.  
- **AOF:** Append-Only File—Redis persistence mode capturing each write.  
- **Hostgssenc/hostssl/host/hostnossl:** HBA record types enforcing transport & auth methods.  
- **Idempotent:** Safe to reapply—same end state without side effects.

---

## “Go / No-Go” Master Checklist

- [ ] HX Root CA present on all clients (`/usr/local/share/ca-certificates/hx-root-ca.crt`).  
- [ ] `pg_hba.conf` rendered from Ansible; `pg_hba_file_rules` shows 0 errors.  
- [ ] `password_encryption = 'scram-sha-256'`, `ssl = on`.  
- [ ] SPN set on truncated machine account; keytab installed; `kvno` SPN succeeds.  
- [ ] GSS SSO `\conninfo` OK for `agent0`.  
- [ ] App path TLS+SCRAM `\conninfo` OK for `hx_app`.  
- [ ] Redis up; AUTH PING PONG; AOF files in `/redispersist/appendonlydir`.  
- [ ] Evidence bundle archived and attached to change record.  
- [ ] Tags/commit pushed in `~/hx-ansible` repo.

---

**When to use this SOP**

- **New environment bring-up (Dev/Test/Prod):** follow §4 + §6.  
- **Drift remediation:** run `pg_auth_enforce.yml` with `--check/--diff`, then apply.  
- **Credential rotations (PG app/Redis):** use vault updates + targeted re-runs (§6.3).  
- **SSO issues:** follow Kerberos section (§4.3) and troubleshooting (§8).



## 12) v1.1 Enhancements (non-blocking)
- **Network controls:** add a short table for nftables/ufw rules restricting 5432/6379 to app/VPN subnets.
- **Observability hooks:** quick tips for `pg_stat_activity` filters and `redis-cli INFO persistence` health checks.
- **HA note:** when adding a read-replica, recommend `target_session_attrs=read-write` on app DSNs.
- **Compliance:** reiterate that evidence bundles are attached to change records and retained per policy.

