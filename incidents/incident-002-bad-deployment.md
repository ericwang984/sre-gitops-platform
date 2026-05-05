# Incident 002: Bad Deployment Causing 500 Errors

## Date
2026-XX-XX

## Duration
8 minutes (14:20 - 14:28 UTC)

## Severity
High - Users experiencing errors

## Summary
Deployment v1.3.0 introduced a breaking change in the `/api/orders` endpoint
causing 500 errors for all requests. The issue was a missing environment variable
that caused the application to fail on startup.

## Impact
- 100% of requests to `/api/orders` returned 500 errors
- Users unable to access order information
- No data loss or corruption
- Affected duration: 8 minutes

## Timeline

| Time | Event |
|------|--------|
| 14:20 | Deployment v1.3.0 completed |
| 14:21 | HighErrorRate alert triggered |
| 14:22 | On-call engineer acknowledged |
| 14:23 | Confirmed 500 errors in logs |
| 14:24 | Identified recent deployment |
| 14:25 | Investigated configuration |
| 14:26 | Found missing environment variable |
| 14:27 | Rollback initiated |
| 14:28 | Rollback completed, errors stopped |

## Root Cause

Version 1.3.0 added a new feature requiring a database connection string environment
variable `DATABASE_URL`. The variable was not defined in the Kubernetes manifests,
causing the application to fail initialization.

## What Went Well

- Alert fired immediately
- Quick rollback decision
- Clear logs showing the error
- Rollback successful

## What Could Be Improved

1. **Configuration validation**: No check for required environment variables
   - Action: Add startup validation for required config

2. **Pre-deployment smoke test**: No test for critical endpoints
   - Action: Add automated smoke test after deployment

3. **Config change review**: Environment variables not reviewed in PR
   - Action: Include ConfigMap changes in PR review checklist

## Action Items

| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| Add config validation on startup | | | Open |
| Add smoke test to deployment | | | Open |
| Update config review checklist | | | Open |

## Related Documents
- [Runbook: Deployment Failure](../runbooks/deployment-failure.md)

## Tags
`deployment`, `500-errors`, `config`, `rollback`
