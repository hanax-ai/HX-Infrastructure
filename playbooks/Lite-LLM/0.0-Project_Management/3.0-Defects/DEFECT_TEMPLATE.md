# Defect Template - LiteLLM Deployment

## Defect ID: DEF-YYYY-MM-DD-XXX
*Format: DEF-<Year>-<Month>-<Day>-<Sequential Number>*

## Defect Summary
**Title**: [Brief, descriptive title of the defect]  
**Date Reported**: YYYY-MM-DD  
**Reporter**: [Name/ID]  
**Severity**: Critical | High | Medium | Low  
**Priority**: P1 | P2 | P3 | P4  
**Status**: New | In Progress | Fixed | Verified | Closed | Deferred  

## Environment Details
**Environment**: Dev-Test | Staging | Production  
**Host(s) Affected**: [e.g., hx-api-server.dev-test.hana-x.ai]  
**Ansible Version**: [e.g., 2.10.7]  
**Python Version**: [e.g., 3.11.x]  
**LiteLLM Version**: [e.g., latest or specific version]  

## Defect Description
### Problem Statement
[Detailed description of what is wrong]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]
4. [Continue as needed]

## Error Details
### Error Message
```
[Paste exact error message here]
```

### Log Entries
```
[Relevant log entries from:
- Ansible output
- System logs (/var/log/syslog, journalctl)
- LiteLLM logs
- Application logs]
```

### Evidence Location
- Screenshot(s): `5.0-Evidence/defects/DEF-YYYY-MM-DD-XXX/`
- Log files: `5.0-Evidence/defects/DEF-YYYY-MM-DD-XXX/logs/`
- Config dumps: `5.0-Evidence/defects/DEF-YYYY-MM-DD-XXX/configs/`

## Impact Analysis
### Affected Components
- [ ] Pre-flight checks
- [ ] Inventory configuration
- [ ] Vault setup
- [ ] Role structure
- [ ] Template rendering
- [ ] Service deployment
- [ ] Network connectivity
- [ ] Authentication/Authorization
- [ ] Other: [Specify]

### Business Impact
[Describe the impact on operations, users, or services]

### Workaround Available
- [ ] Yes - [Describe workaround]
- [ ] No

## Root Cause Analysis
### Preliminary Analysis
[Initial thoughts on what might be causing the issue]

### Investigation Notes
[Document investigation steps and findings]

### Root Cause
[Once identified, document the actual root cause]

## Resolution
### Fix Description
[Describe the fix that was implemented]

### Files Modified
- [ ] Playbook: [filename]
- [ ] Role: [role/task name]
- [ ] Template: [template name]
- [ ] Variable: [variable file]
- [ ] Configuration: [config file]
- [ ] Other: [specify]

### Validation Steps
1. [How to verify the fix works]
2. [Additional test steps]
3. [Regression test requirements]

## Tracking Information
### Related Items
- Requirement ID: [e.g., REQ-3.01]
- Task ID: [e.g., TASK-3.01.02]
- Related Defects: [DEF-YYYY-MM-DD-XXX]
- Backlog Item: [BACKLOG-XXX]

### Timeline
- Reported: YYYY-MM-DD HH:MM
- Assigned: YYYY-MM-DD HH:MM
- Fix Started: YYYY-MM-DD HH:MM
- Fix Completed: YYYY-MM-DD HH:MM
- Verified: YYYY-MM-DD HH:MM
- Closed: YYYY-MM-DD HH:MM

### Assignment History
| Date | Assigned To | Action Taken |
|------|-------------|--------------|
| YYYY-MM-DD | [Name] | Initial assignment |
| YYYY-MM-DD | [Name] | [Action] |

## Lessons Learned
[What can be done to prevent similar issues in the future]

## Attachments
- [ ] Error screenshots
- [ ] Log files
- [ ] Configuration files
- [ ] Test results
- [ ] Other: [specify]

---
*Template Version: 1.0 | Last Updated: 2025-09-15*