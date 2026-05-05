# Incident 003: Memory Leak Causing Pod CrashLoop

## Date
2026-XX-XX

## Duration
25 minutes (09:15 - 09:40 UTC)

## Severity
High - Intermittent availability

## Summary
After deployment v1.4.0, pods began experiencing OOMKilled events and entering
CrashLoopBackOff. Investigation revealed a memory leak in the new orders processing
logic.

## Impact
- 50% of requests failing during incident
- Intermittent availability as pods restarted
- No data loss
- Degrade experience for ~25 minutes

## Timeline

| Time | Event |
|------|--------|
| 09:15 | Deployment v1.4.0 completed |
| 09:18 | PodCrashLooping alert triggered |
| 09:20 | On-call engineer acknowledged |
| 09:22 | Confirmed OOMKilled in pod events |
| 09:25 | Increased memory limits as temporary fix |
| 09:28 | Pods stabilized but memory usage climbing |
| 09:32 | Investigated recent code changes |
| 09:35 | Identified memory leak in order processing |
| 09:37 | Rollback to v1.3.0 initiated |
| 09:40 | Rollback completed, memory usage normal |

## Root Cause

Version 1.4.0 added caching for orders using an in-memory cache. The cache had
no size limit and no eviction policy, causing unbounded memory growth.

```python
# Problematic code in v1.4.0
order_cache = {}  # No size limit!

def get_order(order_id):
    if order_id not in order_cache:
        order_cache[order_id] = db.fetch_order(order_id)
    return order_cache[order_id]
```

## What Went Well

- Alert caught the issue quickly
- Temporary fix (increased limits) bought time
- Root cause identified correctly
- Clean rollback

## What Could Be Improved

1. **Memory profiling**: No baseline for normal memory usage
   - Action: Add memory metrics to dashboard

2. **Resource limits**: Too tight, no headroom for issues
   - Action: Increase memory limits by 50%

3. **Code review**: Cache implementation not reviewed for safety
   - Action: Add caching guidelines to documentation

4. **Load testing**: Didn't catch memory leak
   - Action: Add longer-duration load tests

## Action Items

| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| Fix cache with LRU eviction | | | Open |
| Add memory usage dashboard | | | Open |
| Increase memory limits | | | Open |
| Add caching guidelines | | | Open |
| Extend load test duration | | | Open |

## Related Documents
- [Runbook: Pod CrashLoop](../runbooks/pod-crashloop.md)

## Tags
`memory`, `oomkilled`, `crashloop`, `cache`, `rollback`
