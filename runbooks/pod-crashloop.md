# Runbook: Pod CrashLoop

## Severity
High - Pods continuously restarting

## Symptoms
- Pods in `CrashLoopBackOff` state
- `kubectl get pods` shows high restart counts
- Application unavailable
- Alertmanager firing PodCrashLooping alert

## First Checks

1. **Check pod status**
   ```bash
   kubectl get pods -n prod -l app=demo-api
   kubectl describe pod <pod-name> -n prod
   ```

2. **Check pod logs**
   ```bash
   kubectl logs -n prod <pod-name>
   kubectl logs -n prod <pod-name> --previous
   ```

3. **Check restart count**
   ```bash
   kubectl get pods -n prod -l app=demo-api -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}'
   ```

4. **Check events**
   ```bash
   kubectl get events -n prod --field-selector involvedObject.name=<pod-name>
   ```

## Useful Commands

```bash
# Get pod restart history
kubectl get pods -n prod -l app=demo-api -o wide

# Get pod resource usage
kubectl top pods -n prod

# Check pod YAML
kubectl get pod <pod-name> -n prod -o yaml

# Exec into pod (if running)
kubectl exec -it <pod-name> -n prod -- /bin/sh
```

## Possible Causes

| Cause | Likelihood | Check |
|-------|------------|-------|
| Application error | High | Check logs for exceptions |
| Missing environment variables | Medium | Check deployment env vars |
| Missing ConfigMap/Secret | Medium | Check mounted volumes |
| Liveness probe failing | Medium | Check probe configuration |
| OOMKilled | High | Check memory limits |
| Database connection failure | Medium | Check downstream services |

## Mitigation Steps

1. **If application error**: Fix code and redeploy
   ```bash
   # Check logs for stack traces
   kubectl logs -n prod -l app=demo-api --tail=100
   ```

2. **If OOMKilled**: Increase memory limits
   ```bash
   kubectl set resources deployment demo-api -n prod \
     --limits=memory=512Mi --requests=memory=256Mi
   ```

3. **If liveness probe failing**: Adjust probe thresholds
   ```bash
   # Temporarily disable liveness probe for debugging
   kubectl patch deployment demo-api -n prod -p '{"spec":{"template":{"spec":{"containers":[{"name":"demo-api","livenessProbe":null}]}}}}'
   ```

4. **If config missing**: Check ConfigMaps and Secrets
   ```bash
   kubectl get configmaps -n prod
   kubectl get secrets -n prod
   ```

## Rollback Procedure

```bash
# If issue is with new version, rollback immediately
argocd app rollback demo-api-prod

# Verify
kubectl rollout status deployment/demo-api -n prod
kubectl get pods -n prod -l app=demo-api
```

## Post-Incident Actions

1. Write incident report
2. Add resource monitoring if OOM
3. Add startup validation if app error
4. Improve health check configuration
5. Add pre-deployment smoke tests

## Related Runbooks
- [Deployment Failure](./deployment-failure.md)
- [High Latency](./high-latency.md)
- [Rollback](./rollback.md)

## Last Updated
2026-05-04
