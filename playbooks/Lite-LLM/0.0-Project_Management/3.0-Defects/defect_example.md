# Example Defect: Template Rendering Failure

## Defect ID: DEF-2025-09-15-001

## Summary

**Title**: LiteLLM config template fails to render with undefined variable  
**Date Reported**: 2025-09-15  
**Reporter**: agent0  
**Severity**: High  
**Priority**: P2  
**Status**: Fixed  

## Environment

- **Environment**: Dev-Test
- **Host**: hx-api-server.dev-test.hana-x.ai
- **Ansible Version**: 2.10.7
- **Task**: 03-role-validation/03-render-templates.yml

## Description

The litellm.config.yaml.j2 template failed to render due to undefined variable 'litellm_request_timeout'. The template references this variable but it's not defined in group_vars.

## Error Details

```text
AnsibleUndefinedVariable: 'litellm_request_timeout' is undefined
```

## Resolution

Added default value in template:

```yaml
timeout: {{ litellm_request_timeout | default(600) }}
```

## Tracking

- Related Task: TASK-3.03
- Evidence: 5.0-Evidence/defects/DEF-2025-09-15-001/