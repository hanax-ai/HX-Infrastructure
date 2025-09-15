# LiteLLM Executable Sub-Tasks Execution Guide

This guide explains how to execute the granular sub-tasks for LiteLLM deployment with proper sequencing and dependencies.

## Requirements Traceability

This execution guide implements the following requirements:

- **REQ-3.01**: Pre-Flight Checks and Environment Validation
- **REQ-3.02**: Inventory and Group Variables Setup  
- **REQ-3.03**: Role Structure and Template Validation

Source: `1.0-Requirements/LiteLLM API Gateway — HX API Server_Final.md`

## Overview

The LiteLLM deployment has been broken down from high-level tasks into executable sub-tasks organized in three phases:

1. **Pre-Flight Checks** (01-preflight/) - Implements REQ-3.01
2. **Inventory Setup** (02-inventory/) - Implements REQ-3.02
3. **Role Validation** (03-role-validation/) - Implements REQ-3.03

Each phase contains specific sub-tasks that must be executed in sequence.

## Directory Structure

```text
scope/
├── master-orchestration.yml      # Orchestrates all tasks with dependencies
├── EXECUTION_GUIDE.md           # This guide
└── tasks/
    ├── 1.0-summary-tasks/       # High-level task descriptions
    │   ├── task_3.01_preflight_checks.md
    │   ├── task_3.02_inventory_group_vars.md
    │   └── task_3.03_role_template_validation.md
    └── 2.0-sub-tasks/           # Executable sub-tasks
        ├── 01-preflight/
        │   ├── 01-dns-resolution.yml
        │   ├── 02-network-validation.yml
        │   ├── 03-domain-validation.yml
        │   ├── 04-ca-trust-validation.yml
        │   ├── 05-python-runtime.yml
        │   └── 06-evidence-collection.yml
        ├── 02-inventory/
        │   ├── 01-add-litellm-group.yml
        │   ├── 02-configure-group-vars.yml
        │   ├── 03-setup-vault.yml
        │   ├── 04-quarantine-stray-vaults.yml
        │   └── 05-validate-variables.yml
        └── 03-role-validation/
            ├── 01-verify-role-structure.yml
            ├── 02-validate-templates.yml
            ├── 03-render-templates.yml
            └── 04-document-issues.yml
```

## Execution Methods

### Method 1: Master Orchestration (Recommended)

The easiest way to execute all tasks with proper sequencing:

```bash
cd /home/agent0/hx-ansible
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml
```

This will:

- Execute all phases in order
- Check dependencies between phases
- Stop on failures (unless overridden)
- Generate comprehensive evidence and reports

### Method 2: Phase-by-Phase Execution

Execute specific phases only:

```bash
# Run only pre-flight checks
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml \
  -e "run_inventory=false run_role_validation=false"

# Run only inventory setup
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml \
  -e "run_preflight=false run_role_validation=false"

# Run only role validation
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml \
  -e "run_preflight=false run_inventory=false"
```

### Method 3: Individual Sub-Task Execution

For granular control, run individual sub-tasks:

```bash
# Example: Run only DNS resolution check
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/01-preflight/01-dns-resolution.yml

# Example: Run only vault setup
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/02-inventory/03-setup-vault.yml
```

## Task Dependencies and Sequencing

### Phase 1: Pre-Flight Checks (REQ-3.01)

**Purpose**: Validate infrastructure readiness per Task 3.01 requirements

1. **01-dns-resolution.yml** (TASK-3.01.01)
   - Dependencies: None
   - Validates: DNS resolution for all hosts
   - Evidence: `.evidence/api-preflight/<timestamp>/dns/`

2. **02-network-validation.yml** (TASK-3.01.02)
   - Dependencies: DNS resolution must pass
   - Validates: Network config, connectivity to backends
   - Evidence: `.evidence/api-preflight/<timestamp>/network/`

3. **03-domain-validation.yml** (TASK-3.01.03)
   - Dependencies: Network validation must pass
   - Validates: Domain join, sudo privileges
   - Evidence: `.evidence/api-preflight/<timestamp>/domain/`

4. **04-ca-trust-validation.yml** (TASK-3.01.04)
   - Dependencies: Domain validation must pass
   - Validates: HX Root CA trust
   - Evidence: `.evidence/api-preflight/<timestamp>/ca-trust/`

5. **05-python-runtime.yml** (TASK-3.01.05)
   - Dependencies: CA trust validation must pass
   - Validates: Python 3.11, pip, virtual environment
   - Evidence: `.evidence/api-preflight/<timestamp>/python/`

6. **06-evidence-collection.yml** (TASK-3.01.06)
   - Dependencies: All previous checks
   - Creates: Summary report and evidence archive
   - Evidence: `.evidence/api-preflight/<timestamp>/preflight_summary.txt`

### Phase 2: Inventory Setup (REQ-3.02)

**Purpose**: Configure Ansible inventory and variables

1. **01-add-litellm-group.yml** (TASK-3.02.01)
   - Dependencies: Pre-flight checks complete
   - Action: Adds [litellm] group to inventory
   - Backup: Creates timestamped backup

2. **02-configure-group-vars.yml** (TASK-3.02.02)
   - Dependencies: LiteLLM group added
   - Action: Sets non-secret variables in group_vars
   - Variables: bind_host, port, backends, models, etc.

3. **03-setup-vault.yml** (TASK-3.02.03)
   - Dependencies: Group vars configured
   - Action: Prepares vault for master key
   - **MANUAL STEP REQUIRED**: Add master key to vault

4. **04-quarantine-stray-vaults.yml** (TASK-3.02.04)
   - Dependencies: Vault setup complete
   - Action: Finds and quarantines stray vault files
   - Evidence: `_quarantine/quarantine_report_<timestamp>.txt`

5. **05-validate-variables.yml** (TASK-3.02.05)
   - Dependencies: All previous inventory tasks
   - Validates: All required variables present and valid
   - Report: `/tmp/litellm_variable_validation_<timestamp>.txt`

### Phase 3: Role Validation (REQ-3.03)

**Purpose**: Validate Ansible role and templates

1. **01-verify-role-structure.yml** (TASK-3.03.01)
   - Dependencies: Inventory setup complete
   - Action: Creates/verifies role directory structure
   - Report: `/tmp/litellm_role_structure_<timestamp>.txt`

2. **02-validate-templates.yml** (TASK-3.03.02)
   - Dependencies: Role structure verified
   - Action: Validates template syntax and variables
   - Report: `/tmp/litellm_template_validation_<timestamp>.txt`

3. **03-render-templates.yml** (TASK-3.03.03)
   - Dependencies: Templates validated
   - Action: Renders templates with current variables
   - Evidence: `.evidence/litellm_role_validation/<timestamp>/`

4. **04-document-issues.yml** (TASK-3.03.04)
   - Dependencies: Templates rendered
   - Action: Documents any issues found
   - Reports: Full report, analysis, remediation script

## Manual Intervention Points

### 1. Vault Configuration (Phase 2, Step 3)

After running inventory setup, you must manually add the master key:

```bash
# Generate a secure key
openssl rand -hex 32 | sed 's/^/sk-/'

# Edit the vault
ansible-vault edit inventories/group_vars/all/vault.yml

# Add the key
litellm_master_key: "sk-<your-generated-key>"
```

### 2. Issue Resolution (If needed)

If validation fails, review the reports and fix issues:

```bash
# Check validation report
cat /tmp/litellm_variable_validation_*.txt

# Check role issues
cat .evidence/litellm_role_validation/*/issues/full_report.txt

# Run remediation script if provided
.evidence/litellm_role_validation/*/issues/remediation.sh
```

## Evidence and Audit Trail

All tasks generate evidence for audit and troubleshooting:

```text
.evidence/
├── api-preflight/<timestamp>/          # Pre-flight check results
│   ├── dns/                           # DNS validation
│   ├── network/                       # Network validation
│   ├── domain/                        # Domain validation
│   ├── ca-trust/                      # CA trust validation
│   ├── python/                        # Python runtime validation
│   └── preflight_summary.txt          # Overall summary
├── litellm_role_validation/<timestamp>/ # Role validation results
│   ├── litellm.config.yaml            # Rendered config
│   ├── litellm.env                    # Rendered environment
│   ├── render_validation_report.txt   # Validation report
│   └── issues/                        # Issues and remediation
└── litellm_orchestration_<timestamp>.txt # Master execution summary
```

## Troubleshooting

### Common Issues

1. **DNS Resolution Failures**
   - Check `/etc/resolv.conf` on target host
   - Verify DNS servers can resolve internal domains

2. **Variable Not Found**
   - Check exact variable names in templates
   - Ensure variables are in correct group_vars file

3. **Vault Not Encrypted**
   - Run: `ansible-vault encrypt inventories/group_vars/all/vault.yml`
   - Set vault password in `ansible.cfg` or use `--ask-vault-pass`

4. **Template Rendering Errors**
   - Check for typos in variable names
   - Verify Jinja2 syntax in templates
   - Review `.evidence/litellm_role_validation/*/issues/`

### Re-running After Fixes

```bash
# Re-run complete orchestration
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml

# Continue despite failures (for debugging)
ansible-playbook playbooks/Lite-LLM/scope/master-orchestration.yml \
  -e "skip_on_failure=true"

# Re-run specific failed task
ansible-playbook playbooks/Lite-LLM/scope/tasks/2.0-sub-tasks/<phase>/<task>.yml
```

## Next Steps After Successful Validation

Once all tasks complete successfully:

1. **Deploy LiteLLM**:

   ```bash
   ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_enforce.yml \
     --limit hx-api-server --ask-vault-pass
   ```

2. **Run Smoke Tests**:

   ```bash
   ansible-playbook playbooks/Lite-LLM/litellm_smoke_test.yml --ask-vault-pass
   ```

3. **Verify Service**:

   ```bash
   curl -H "Authorization: Bearer <your-master-key>" \
     http://hx-api-server.dev-test.hana-x.ai:4000/v1/models
   ```

## Best Practices

1. **Always run master orchestration first** - It handles dependencies correctly
2. **Review evidence after each phase** - Don't proceed if issues exist
3. **Keep vault password secure** - Use password file or vault service
4. **Document any manual changes** - Update group_vars if needed
5. **Archive evidence** - Keep for compliance and troubleshooting

## Support

For issues or questions:

1. Check evidence files for detailed error information
2. Review high-level task descriptions in `1.0-summary-tasks/`
3. Consult the main README at `playbooks/Lite-LLM/README_LITELLM.md`
