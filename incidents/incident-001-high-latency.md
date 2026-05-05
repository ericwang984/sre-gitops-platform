# Incident 001: High Latency After Deployment v1.2.0

## Date
2026-XX-XX

## Duration
12 minutes (10:03 - 10:15 UTC)

## Severity
Medium - Degraded performance, no data loss

## Summary
After deploying version v1.2.0, p95 latency increased from 120ms to 1.8s.
The issue was traced to an inefficient database query introduced in the new version.

## Impact
- API requests were slower for approximately 12 minutes
- No data loss occurred
- Error rate remained below 1%
- User-facing: Slower page loads, some timeout errors

## Timeline

| Time | Event |
|------|--------|
| 10:00 | Deployment started through Argo CD |
| 10:02 | Deployment completed, new pods healthy |
| 10:03 | p95 latency alert triggered (1.2s) |
| 10:05 | On-call engineer acknowledged alert |
| 10:06 | Checked Grafana dashboard - confirmed latency spike |
| 10:07 | Checked logs - no errors, just slow responses |
| 10:08 | Checked recent deployment - identified v1.2.0 |
| 10:09 | Decided to rollback to v1.1.0 |
| 10:10 | Rollback initiated via Argo CD |
| 10:12 | Rollback completed |
| 10:15 | Latency returned to normal (~120ms) |

## Root Cause

The new version (v1.2.0) introduced a change in `/api/orders` that added an
additional database query without proper indexing. The N+1 query problem caused
exponential database load as order count increased.

```python
# Problematic code in v1.2.0
for order in orders:
    order.items = db.get_items(order.id)  # N+1 query problem
```

## What Went Well

- Alert fired quickly (within 1 minute of threshold breach)
- Grafana dashboard clearly showed the latency spike
- Argo CD rollback completed smoothly
- No data loss or corruption
- Incident timeline was well-documented

## What Could Be Improved

1. **Pre-deployment testing**: No performance test for `/api/orders`
   - Action: Add load test to CI pipeline for all endpoints

2. **Database query review**: No code review focus on query efficiency
   - Action: Add query plan review to PR checklist

3. **Canary deployment**: Full rollout caught everyone at once
   - Action: Implement canary deployments before full rollout

4. **Database monitoring**: No database-specific metrics/alerts
   - Action: Add PostgreSQL slow query monitoring

## Action Items

| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| Add load test for `/api/orders` | | | Open |
| Fix N+1 query in code | | | Open |
| Add database query monitoring | | | Open |
| Implement canary deployments | | | Open |
| Update runbook with this pattern | | | Open |

## Related Documents
- [Runbook: High Latency](../runbooks/high-latency.md)
- [Grafana Dashboard: Application Metrics](http://localhost:3000/d/app-metrics)

## Tags
`latency`, `deployment`, `rollback`, `database`, `n+1-query`
