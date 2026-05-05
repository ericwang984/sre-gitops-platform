# Runbook: High Latency

## Severity
Medium - May impact user experience

## Symptoms
- p95 latency above 1 second
- p99 latency above 2 seconds
- Grafana dashboard shows increased request duration
- User complaints about slow API response

## First Checks

1. **Check current latency metrics**
   ```bash
   # Check Prometheus for current latency
   kubectl port-forward -n observability svc/prometheus 9090:9090
   # Open http://localhost:9090 and query:
   # histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
   ```

2. **Check pod resource usage**
   ```bash
   kubectl top pods -n prod
   kubectl describe pods -n prod -l app=demo-api
   ```

3. **Check recent deployments**
   ```bash
   argocd app history demo-api-prod
   kubectl rollout history deployment/demo-api -n prod
   ```

4. **Check application logs**
   ```bash
   kubectl logs -n prod -l app=demo-api --tail=100 --since=5m
   ```

5. **Check downstream dependencies**
   ```bash
   # If database/redis added, check their metrics
   ```

## Useful Commands

```bash
# Get current replica count
kubectl get deployment demo-api -n prod -o jsonpath='{.spec.replicas}'

# Scale up replicas
kubectl scale deployment demo-api -n prod --replicas=5

# Check HPA status (if configured)
kubectl get hpa -n prod

# Port forward to local for testing
kubectl port-forward -n prod svc/demo-api 8080:80

# Test latency locally
time curl http://localhost:8080/api/orders
```

## Possible Causes

| Cause | Likelihood | Check |
|-------|------------|-------|
| Recent bad deployment | High | Check deployment history |
| CPU throttling | Medium | Check `container_cpu_cfs_throttled_seconds_total` |
| Memory pressure | Medium | Check `container_memory_usage_bytes` |
| Downstream latency | Low | Check database/redis metrics |
| Node resource saturation | Low | Check node metrics |

## Mitigation Steps

1. **Quick fix**: Scale replicas
   ```bash
   kubectl scale deployment demo-api -n prod --replicas=5
   ```

2. **If recent deployment**: Rollback
   ```bash
   argocd app rollback demo-api-prod
   # OR
   kubectl rollout undo deployment/demo-api -n prod
   ```

3. **If resource constrained**: Increase limits
   ```bash
   kubectl set resources deployment demo-api -n prod \
     --limits=cpu=1000m,memory=512Mi \
     --requests=cpu=200m,memory=256Mi
   ```

4. **If persistent**: Investigate code with profiling

## Rollback Procedure

### Via Argo CD (Preferred)
```bash
# List history
argocd app history demo-api-prod

# Rollback to specific version
argocd app rollback demo-api-prod <revision-number>

# Or via UI:
# 1. Open Argo CD UI
# 2. Select application: demo-api-prod
# 3. Click "App History"
# 4. Click rollback on previous healthy version
```

### Via kubectl (Emergency)
```bash
kubectl rollout undo deployment/demo-api -n prod

# Check rollback status
kubectl rollout status deployment/demo-api -n prod
```

## Post-Incident Actions

1. Write incident report in `/incidents/` directory
2. Add/update alert if none fired
3. Improve Grafana dashboard if visibility was lacking
4. Add automated test if this was a code regression
5. Update this runbook with lessons learned

## Related Runbooks
- [Deployment Failure](./deployment-failure.md)
- [Pod CrashLoop](./pod-crashloop.md)
- [Rollback](./rollback.md)

## Last Updated
2026-05-04
