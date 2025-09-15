# Task 3.02 - "Inventory and Group Vars Setup"

### Task Overview

- **Task ID**: 3.02
- **Task Name**: Inventory and Group Vars Setup
- **Description**: Prepare and validate Ansible inventory and group variables for LiteLLM deployment, including all required non-secret and secret parameters.
- **Priority**: High
- **Estimated Duration**: 20-30 minutes

### Dependencies & Prerequisites

- **Predecessor Tasks**: 3.01 (Pre-Flight Checks)
- **Dependencies**:
  - System dependencies: Ansible control node access
  - Data dependencies: Hostnames, model list, master key
  - Personnel dependencies: Ops engineer with vault access

### Execution Environment

- **Target Server/Environment**: Ansible inventory (dev.ini)
- **Required Permissions**: Edit access to inventory and group_vars
- **Resource Requirements**: N/A

### Task Activities & Subtasks
1. Add `[litellm]` group to `inventories/dev.ini`
2. Populate `group_vars/all/main.yml` with bind host, port, backends, models
3. Store `litellm_master_key` in encrypted `group_vars/all/vault.yml`
4. Quarantine stray/old vault files
5. Validate all required variables are present

### Implementation Requirements (SOLID Principles)
- Single Responsibility: Each file/variable is managed by a dedicated task
- Open/Closed: Easily extendable for new variables
- Liskov Substitution: Can be reused for other environments
- Interface Segregation: Secrets and non-secrets are separated
- Dependency Inversion: Use Ansible abstractions for file management

### Configuration Files
- Config File Location: `inventories/dev.ini`, `group_vars/all/main.yml`, `group_vars/all/vault.yml`
- Environment Variables: N/A
- Parameter Settings: `litellm_bind_host`, `litellm_bind_port`, `litellm_backends`, `litellm_models`, `litellm_master_key`

### Success Criteria
- Primary Success Metrics: All required variables present and correct
- Acceptance Criteria: Inventory and group_vars are ready for playbook execution
- Performance Benchmarks: N/A
- Quality Gates: No missing or duplicate variables, secrets not in plain text

### Testing & Validation
- Unit Tests: Ansible syntax check
- Integration Tests: Playbook dry-run with `--check`
- System Tests: N/A
- User Acceptance Tests: N/A
- Test Data Requirements: Valid hostnames, model list, master key

### Results Capture
- Output Location: N/A
- Log Files: Ansible playbook logs
- Metrics Collection: N/A
- Documentation: Update project docs with inventory/group_vars structure
- Artifacts: Updated inventory and group_vars files

### Rollback Plan
- Rollback Triggers: Invalid or missing variables
- Rollback Procedures: Restore previous inventory/group_vars from backup
- Recovery Time Objective: <10 minutes

### Sign-off
- Completion Date: [To be filled]
- Status: Not Started
