#!/usr/bin/env bash
#
# Script: Write the final files for LiteLLM Integration
# Purpose: Deploy final configuration files for the hx_litellm_proxy Ansible role
# Usage: bash playbooks/Integration/Write\ the\ final\ files.md
# Author: HX Infrastructure Team
# Date: September 2025
# License: Internal use only - HX Platform
# Contact: infrastructure@hana-x.ai
#
# Description: This script writes the final versions of Ansible role files
#              for the LiteLLM proxy integration, including tasks, templates,
#              and systemd service configurations.

# Run from repo root on the control node
set -euo pipefail

# Detect role directory (new layout preferred)
if [ -d playbooks/Lite-LLM/roles/hx_litellm_proxy ]; then
  ROLE_DIR="playbooks/Lite-LLM/roles/hx_litellm_proxy"
elif [ -d roles/hx_litellm_proxy ]; then
  ROLE_DIR="roles/hx_litellm_proxy"
else
  echo "ERROR: hx_litellm_proxy role not found"; exit 2
fi

mkdir -p backups
TS="$(date -u +%Y-%m-%d-%H%M%S)"
for f in tasks/main.yml tasks/systemd.yml templates/litellm.env.j2; do
  [ -f "$ROLE_DIR/$f" ] && install -m 0644 "$ROLE_DIR/$f" "backups/${f//\//_}.bak.${TS}" || true
done

# --- roles/hx_litellm_proxy/tasks/main.yml (FINAL) ---
tee "$ROLE_DIR/tasks/main.yml" >/dev/null <<'YAML'
---
- name: Ensure service user and group
  user: { name: litellm, shell: /usr/sbin/nologin, create_home: false }

- name: Install runtime prerequisites (Python 3.12 + pip + DB driver)
  apt:
    name: [python3.12-venv, python3-pip, python3-psycopg2]
    state: present
    update_cache: true

- name: Create application directory with correct ownership
  file:
    path: /opt/litellm
    state: directory
    mode: '0755'
    owner: litellm
    group: litellm

- name: Create venv as the litellm user
  become: true
  become_user: litellm
  command: python3.12 -m venv /opt/litellm
  args: { creates: /opt/litellm/bin/activate }

- name: Install/upgrade LiteLLM with proxy extras
  command: /opt/litellm/bin/pip install --upgrade "litellm[proxy]==1.77.1"

- name: Config directory
  file: { path: /etc/litellm, state: directory, mode: '0755' }

- name: Render env file with correct permissions
  template:
    src: litellm.env.j2
    dest: /etc/litellm/litellm.env
    mode: '0640'
    owner: root
    group: litellm

- name: Render proxy config with correct permissions
  template:
    src: litellm.config.yaml.j2
    dest: /etc/litellm/config.yaml
    mode: '0640'
    owner: root
    group: litellm
  notify: Restart litellm
YAML

# --- roles/hx_litellm_proxy/tasks/systemd.yml (FINAL) ---
tee "$ROLE_DIR/tasks/systemd.yml" >/dev/null <<'YAML'
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
      Group=litellm
      EnvironmentFile=/etc/litellm/litellm.env
      WorkingDirectory=/opt/litellm
      ExecStart=/opt/litellm/bin/litellm --config /etc/litellm/config.yaml --host ${LITELLM_HOST} --port ${LITELLM_PORT}
      Restart=always
      RestartSec=5
      # Hardening
      NoNewPrivileges=true
      ProtectSystem=strict
      ProtectHome=true
      PrivateTmp=true

      [Install]
      WantedBy=multi-user.target
  register: unit

- name: daemon-reload when unit changed
  systemd: { daemon_reload: true }
  when: unit.changed

- name: Enable + start + assert active
  systemd: { name: litellm, state: started, enabled: true }

- name: Verify listening port
  wait_for:
    port: "{{ litellm_bind_port }}"
    host: "{{ litellm_bind_host }}"
    state: started
    timeout: 30

# Handler target (from tasks/main.yml notify)
- name: Restart litellm
  systemd:
    name: litellm
    state: restarted
  listen: Restart litellm
YAML

# --- roles/hx_litellm_proxy/templates/litellm.env.j2 (FINAL) ---
tee "$ROLE_DIR/templates/litellm.env.j2" >/dev/null <<'J2'
# Non-secret runtime toggles only; auth lives in /etc/litellm/config.yaml
LITELLM_HOST={{ litellm_bind_host }}
LITELLM_PORT={{ litellm_bind_port }}
# Optional local telemetry toggle
LITELLM_TELEMETRY=false
J2
