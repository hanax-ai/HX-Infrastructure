# LiteLLM Project Structure

This document describes the consolidated structure for the LiteLLM deployment within the HX Infrastructure.

## Directory Layout

```text
playbooks/Lite-LLM/
├── README_LITELLM.md           # Main deployment guide
├── STRUCTURE.md                # This file - structure documentation
│
├── litellm_preflight.yml       # Pre-flight checks playbook
├── litellm_inventory_setup.yml # Inventory and group vars setup
├── litellm_role_validation.yml # Role structure validation
├── litellm_enforce.yml         # Main deployment playbook
├── litellm_smoke_test.yml      # Post-deployment testing
│
├── roles/
│   └── hx_litellm_proxy/       # LiteLLM proxy Ansible role
│       ├── defaults/
│       │   └── main.yml        # Default variables
│       ├── handlers/
│       │   └── main.yml        # Service handlers
│       ├── meta/
│       │   └── main.yml        # Role metadata
│       ├── tasks/
│       │   ├── main.yml        # Main tasks
│       │   └── systemd.yml     # Systemd service setup
│       └── templates/
│           ├── litellm.config.yaml.j2  # LiteLLM configuration
│           └── litellm.env.j2          # Environment variables
│
├── x-plan/                     # Planning and design documents
│   └── LiteLLM API Gateway — HX API Server_Final.md
│
└── x-tasks/                    # Original task specifications
    ├── task_3.01_preflight_checks.md
    ├── task_3.02_inventory_group_vars.md
    └── task_3.03_role_template_validation.md
```

## Rationale for Consolidation

1. **Self-contained deployment**: All LiteLLM-related artifacts are in one location
2. **Easy portability**: The entire directory can be moved or copied as a unit
3. **Clear boundaries**: Separates LiteLLM from other infrastructure components
4. **Simplified maintenance**: All related files are easily discoverable

## Directory Descriptions

### x-plan/

Contains the original planning and design documents that guided the implementation:

- `LiteLLM API Gateway — HX API Server_Final.md` - Comprehensive design document with architecture decisions, configuration examples, and deployment strategy

### x-tasks/

Contains the original task specifications that were converted into executable playbooks:

- `task_3.01_preflight_checks.md` - Specifications for pre-flight validation
- `task_3.02_inventory_group_vars.md` - Specifications for inventory setup
- `task_3.03_role_template_validation.md` - Specifications for role validation

These directories preserve the original planning artifacts for reference and audit purposes.

## Playbook Execution Order

1. **litellm_preflight.yml** - Validates prerequisites
2. **litellm_inventory_setup.yml** - Configures inventory and variables
3. **litellm_role_validation.yml** - Creates and validates role structure
4. **litellm_enforce.yml** - Deploys LiteLLM using the local role
5. **litellm_smoke_test.yml** - Validates the deployment

## Key Paths

- **Playbooks**: `/home/agent0/hx-ansible/playbooks/Lite-LLM/`
- **Role**: `/home/agent0/hx-ansible/playbooks/Lite-LLM/roles/hx_litellm_proxy/`
- **Evidence**: `/home/agent0/hx-ansible/.evidence/litellm_*/`
- **Main inventory**: `/home/agent0/hx-ansible/inventories/dev.ini`
- **Group vars**: `/home/agent0/hx-ansible/inventories/group_vars/all/`

## Integration with Main Project

While LiteLLM is consolidated in its own directory, it still integrates with the main HX Infrastructure:

- Uses the main inventory file (`inventories/dev.ini`)
- Shares group variables (`inventories/group_vars/all/`)
- Follows the same Ansible patterns and conventions
- Evidence is stored in the main evidence directory

## Running Playbooks

From the main hx-ansible directory:

```bash
# Example: Run preflight checks
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_preflight.yml

# Example: Deploy LiteLLM
ansible-playbook -i inventories/dev.ini playbooks/Lite-LLM/litellm_enforce.yml \
  --limit hx-api-server --ask-vault-pass
```

## Future Enhancements

- Add `tests/` directory for role testing with molecule
- Add `docs/` directory for API documentation
- Add `examples/` directory with usage examples
- Consider adding `collections/` if we package this as an Ansible collection