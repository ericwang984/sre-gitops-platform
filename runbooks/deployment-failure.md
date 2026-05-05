# Runbook: Deployment Failure

## Severity
High - New versions not deploying

## Symptoms
- New pods not starting
- Deployment stuck in progress
- Argo CD shows sync errors
- Old version still running

## First Checks

1. **Check deployment status**
   ```bash
   kubectl get deployment demo-api -n prod
   kubectl describe deployment demo-api -n prod
   ```

2. **Check pod status**
   ```bash
   kubectl get pods -n prod -l app=demo-api
   kubectl describe pod <pod-name> -n prod
   ```

3. **Check Argo CD sync status**
   ```bash
   argocd app get demo-api-prod
   ```

4. **Check recent events**
   ```bash
   kubectl get events -n prod --sort-by='.lastTimestamp'
   ```

## Useful Commands

```bash
# View deployment logs
kubectl logs -n prod -l app=demo-api --all-containers=true

# Get specific pod logs
kubectl logs -n prod <pod-name> --previous

# Check resource quotas
kubectl get resourcequota -n prod

# Check limit ranges
kubectl get limitrange -n prod
```

## Possible Causes

| Cause | Likelihood | Check |
|-------|------------|-------|
| Image pull failure | High | Check image name/tag, registry access |
| Resource limits | Medium | Check requests/limits vs available resources |
| Config error | Medium | Check environment variables, ConfigMaps |
| Health check failure | Medium | Check probe configuration |
| Crash on startup | High | Check application logs for errors |

## Mitigation Steps

1. **If image pull fails**: Check image tag and registry access
   ```bash
   # Test image pull manually
   docker pull ghcr.io/ericwang984/sre-demo-app:<tag>
   ```

2. **If pods crashing**: Check logs for errors
   ```bash
   kubectl logs -n prod -l app=demo-api --tail=50
   ```

3. **If resource constrained**: Increase limits or scale other workloads
   ```bash
   kubectl top nodes
   kubectl top pods -n prod
   ```

4. **Quick rollback**: Revert to previous version
   ```bash
   argocd app rollback demo-api-prod
   ```

## Rollback Procedure

```bash
# Via Argo CD
argocd app rollback demo-api-prod

# Via kubectl
kubectl rollout undo deployment/demo-api -n prod

# Verify rollback
kubectl rollout status deployment/demo-api -n prod
```

## Post-Incident Actions

1. Document root cause in incident report
2. Fix image build process if needed
3. Add pre-deployment validation
4. Update this runbook with lessons learned

## Related Runbooks
- [High Latency](./high-latency.md)
- [Pod CrashLoop](./pod-crashloop.md)
- [Rollback](./rollback.md)

## Last Updated
2026-05-04
