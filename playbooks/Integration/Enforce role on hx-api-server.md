# Use your newer playbook path if present
PLAYBOOK="playbooks/Lite-LLM/litellm_enforce.yml"
[ -f "$PLAYBOOK" ] || PLAYBOOK="playbooks/litellm_enforce.yml"

# Dry-run (sanity)
ansible-playbook -i inventories/dev.ini "$PLAYBOOK" --limit hx-api-server -t critical --check --diff

# Apply
ansible-playbook -i inventories/dev.ini "$PLAYBOOK" --limit hx-api-server -t critical,high

# Quick service check
ssh hx-api-server.dev-test.hana-x.ai "sudo systemctl status --no-pager litellm && ss -ltn '( sport = :4000 )'"
