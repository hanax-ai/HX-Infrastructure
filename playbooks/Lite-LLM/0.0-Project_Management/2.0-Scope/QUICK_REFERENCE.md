# LiteLLM Sub-Tasks Quick Reference

This quick reference provides commands for executing LiteLLM deployment tasks with traceability to requirements.

## Requirements Traceability

- **REQ-3.01**: Pre-Flight Checks and Environment Validation
- **REQ-3.02**: Inventory and Group Variables Setup  
- **REQ-3.03**: Role Structure and Template Validation

## Complete Execution (All Phases)

```bash
cd /home/agent0/hx-ansible
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml
```

## Phase-Specific Execution

### Pre-Flight Checks Only (REQ-3.01)

```bash
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml \
  -e "run_inventory=false run_role_validation=false"
```

### Inventory Setup Only (REQ-3.02)

```bash
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml \
  -e "run_preflight=false run_role_validation=false"
```

### Role Validation Only (REQ-3.03)

```bash
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml \
  -e "run_preflight=false run_inventory=false"
```

## Individual Sub-Tasks

### Pre-Flight Sub-Tasks (REQ-3.01)

```bash
# TASK-3.01.01: DNS Resolution
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/01-preflight/01-dns-resolution.yml

# TASK-3.01.02: Network Validation
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/01-preflight/02-network-validation.yml

# TASK-3.01.03: Domain Validation
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/01-preflight/03-domain-validation.yml

# TASK-3.01.04: CA Trust Validation
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/01-preflight/04-ca-trust-validation.yml

# TASK-3.01.05: Python Runtime
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/01-preflight/05-python-runtime.yml

# TASK-3.01.06: Evidence Collection
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/01-preflight/06-evidence-collection.yml
```

### Inventory Sub-Tasks (REQ-3.02)

```bash
# TASK-3.02.01: Add LiteLLM Group
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/02-inventory/01-add-litellm-group.yml

# TASK-3.02.02: Configure Group Vars
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/02-inventory/02-configure-group-vars.yml

# TASK-3.02.03: Setup Vault
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/02-inventory/03-setup-vault.yml

# TASK-3.02.04: Quarantine Stray Vaults
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/02-inventory/04-quarantine-stray-vaults.yml

# TASK-3.02.05: Validate Variables
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/02-inventory/05-validate-variables.yml
```

### Role Validation Sub-Tasks (REQ-3.03)

```bash
# TASK-3.03.01: Verify Role Structure
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/03-role-validation/01-verify-role-structure.yml

# TASK-3.03.02: Validate Templates
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/03-role-validation/02-validate-templates.yml

# TASK-3.03.03: Render Templates
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/03-role-validation/03-render-templates.yml

# TASK-3.03.04: Document Issues
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/03-role-validation/04-document-issues.yml
```

## Manual Steps Required

### After Inventory Setup

```bash
# Generate master key
openssl rand -hex 32 | sed 's/^/sk-/'

# Add to vault
ansible-vault edit inventories/group_vars/all/vault.yml

# Add line:
litellm_master_key: "sk-<your-generated-key>"
```

## Evidence Locations

- Pre-flight (REQ-3.01): `.evidence/api-preflight/<timestamp>/`
- Role validation (REQ-3.03): `.evidence/litellm_role_validation/<timestamp>/`
- Orchestration summary: `.evidence/litellm_orchestration_<timestamp>.txt`
- Project evidence: `0.0-Project_Management/5.0-Evidence/`

## After Successful Validation

```bash
# Deploy LiteLLM
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_enforce.yml \
  --limit hx-api-server --ask-vault-pass

# Run smoke tests
ansible-playbook playbooks/Lite-LLM/litellm_smoke_test.yml --ask-vault-pass

# Test the API
curl -H "Authorization: Bearer <your-master-key>" \
  http://hx-api-server.dev-test.hana-x.ai:4000/v1/models
```

## Troubleshooting Options

```bash
# Continue on failures (for debugging)
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml \
  -e "skip_on_failure=true"

# Run with verbose output
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml -vvv

# Check specific phase status
grep -A5 "Task Execution Status" .evidence/litellm_orchestration_*.txt | tail -6
```
