# Changelog - hx_litellm_proxy Role

All notable changes to the hx_litellm_proxy role will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Updated minimum Ansible version from 2.10 to 2.17 to align with current supported ansible-core releases
- Ansible 2.10 reached End of Life and is no longer supported
- This change ensures compatibility with modern Ansible features and security updates

### Technical Notes
- Ansible 2.17 is part of the ansible-core release series
- Users running older Ansible versions will need to upgrade to use this role
- No breaking changes in role functionality, only minimum version requirement updated

## [1.0.0] - 2025-09-15

### Added
- Initial release of hx_litellm_proxy role
- Support for LiteLLM OpenAI-compatible proxy deployment
- Integration with Ollama backends
- Systemd service management
- Configuration templating for litellm.config.yaml and litellm.env