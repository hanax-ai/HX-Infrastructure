# Project Engineering Rules

**Rule 1: Always check for application/software versions before installing or upgrading.**
- For example, before running `sudo apt install -y ansible-core`, check if Ansible is already installed and note its version:
  ```bash
  ansible --version
  ```
- This prevents unnecessary changes and ensures version consistency across environments.


**Rule 2: Never make assumptions—ask for clarification if details are missing.**
Always confirm requirements, names, and values with the user or documentation before proceeding. This prevents errors and ensures accuracy in all engineering tasks.


**Rule 3: Create timestamped backups before making configuration changes.**

- Always backup configuration files before modifying them using a consistent naming convention:

  ```bash
  cp config.yml config.yml.bak.$(date +%Y%m%d-%H%M%S)
  # Example: config.yml.bak.20250915-143022
  ```

- This enables quick rollback and provides an audit trail of changes.


**Rule 4: Document all changes with clear, descriptive commit messages.**

- Include issue IDs and context in commit messages:

  ```text
  Fix: Correct template variable mappings in LiteLLM validation [#123]
  
  - Updated litellm_port to litellm_bind_port
  - Removed undefined variables from test_vars
  - Added missing timeout and retry configurations
  ```

- This ensures traceability and helps future maintainers understand the changes.


**Rule 5: Test changes in non-production environments first.**

- Always validate changes in development or test environments before production deployment
- Record test results and validation steps:

  ```yaml
  # Test performed: 2025-09-15
  # Environment: dev
  # Result: Successfully deployed LiteLLM with all health checks passing
  # Validation: curl http://localhost:8000/health returned 200 OK
  ```

- This prevents production incidents and ensures changes work as expected.


(Add additional rules below as needed.)
