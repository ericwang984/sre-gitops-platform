# Runbook: Rollback

## Severity
Critical - Reverting failed deployment

## When to Use
- New deployment causing errors or latency
- Automated rollback needed
- Quick recovery from bad release

## Rollback Methods

### Method 1: Argo CD (Recommended)

**Via CLI:**
```bash
# List deployment history
argocd app history demo-api-prod

# Rollback to specific revision
argocd app rollback demo-api-prod <revision-number>

# Watch rollback progress
argocd app get demo-api-prod --watch
```

**Via UI:**
1. Open Argo CD UI at `https://argocd.<domain>`
2. Select application: `demo-api-prod`
3. Click "App History" or "History"
4. Find previous healthy version
5. Click "Rollback" on that revision
6. Click "OK" to confirm

### Method 2: kubectl (Emergency)

```bash
# Rollback to previous revision
kubectl rollout undo deployment/demo-api -n prod

# Rollback to specific revision
kubectl rollout undo deployment/demo-api -n prod --to-revision=2

# Watch rollback status
kubectl rollout status deployment/demo-api -n prod

# Verify pods are running
kubectl get pods -n prod -l app=demo-api
```

### Method 3: Git Revert (GitOps)

```bash
# In your GitOps repository
git log --oneline
git revert <commit-hash>
git push origin main

# Argo CD will auto-sync the reverted change
```

## Rollback Verification

```bash
# Check rollback status
kubectl rollout status deployment/demo-api -n prod

# Verify pods are healthy
kubectl get pods -n prod -l app=demo-api

# Check application responds
kubectl port-forward -n prod svc/demo-api 8080:80
curl http://localhost:8080/health

# Check metrics
kubectl port-forward -n observability svc/prometheus 9090:9090
# Query: up{namespace="prod",app="demo-api"}
```

## Common Issues

### Issue: Rollback stuck
```bash
# Check rollout status
kubectl rollout status deployment/demo-api -n prod

# Cancel rollout if needed
kubectl rollout undo deployment/demo-api -n prod --dry-run=server
```

### Issue: Pods not starting after rollback
```bash
# Check pod events
kubectl describe pod -n prod -l app=demo-api

# Check pod logs
kubectl logs -n prod -l app=demo-api

# May need to rollback to earlier revision
kubectl rollout undo deployment/demo-api -n prod --to-revision=<revision>
```

### Issue: Image not found
```bash
# Check image tags in deployment
kubectl get deployment demo-api -n prod -o jsonpath='{.spec.template.spec.containers[0].image}'

# May need to update image in GitOps repo
```

## Post-Rollback Actions

1. **Verify system health**
   ```bash
   # Check all pods
   kubectl get pods -n prod

   # Check metrics
   kubectl top pods -n prod
   ```

2. **Document the rollback**
   - Create incident report
   - Note which revision was rolled back
   - Record rollback time and impact

3. **Prevent recurrence**
   - Add tests to CI pipeline
   - Improve canary deployment
   - Add feature flags for risky changes

4. **Fix the bad version**
   - Create hotfix branch
   - Test locally
   - Deploy to dev first
   - Then deploy to prod

## Rollback Decision Tree

```
Is the new deployment causing issues?
│
├── YES → Is there user impact?
│   │
│   ├── YES → ROLLBACK IMMEDIATELY
│   │        │
│   │        ├── Use Argo CD UI for fastest rollback
│   │        └── Verify health immediately
│   │
│   └── NO → Can issue be fixed quickly?
│       │
│       ├── YES → Fix and redeploy
│       └── NO → ROLLBACK
│
└── NO → Continue monitoring
```

## Related Runbooks
- [High Latency](./high-latency.md)
- [Deployment Failure](./deployment-failure.md)
- [Pod CrashLoop](./pod-crashloop.md)

## Last Updated
2026-05-04
