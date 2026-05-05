# GitOps Flow

## What is GitOps?

GitOps is an operational framework that combines:
- **Git** as the single source of truth
- **Declarative specifications** (Kubernetes manifests)
- **Automated sync** from Git to cluster
- **Self-healing** (drift detection and correction)

## GitOps Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Git Repository                          │
│                        (Source of Truth)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ git push
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                           Argo CD                                │
│                       (GitOps Operator)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐      ┌────────────────┐                     │
│  │  Watch Git     │─────>│ Detect Changes │                     │
│  │  Repository    │      │               │                     │
│  └────────────────┘      └───────┬───────┘                     │
│                                  │                              │
│                                  ▼                              │
│  ┌────────────────┐      ┌────────────────┐                     │
│  │  Compare State │─────>│    Sync/Apply  │                     │
│  │  Git vs Cluster│      │   to Cluster   │                     │
│  └────────────────┘      └───────┬───────┘                     │
│                                  │                              │
│                                  ▼                              │
│  ┌────────────────┐      ┌────────────────┐                     │
│  │   Self-Heal    │<─────│   Monitor      │                     │
│  │   (Auto Fix)   │      │   Cluster      │                     │
│  └────────────────┘      └────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ apply manifests
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                         │
└─────────────────────────────────────────────────────────────────┘
```

## Key GitOps Principles

### 1. Declarative
- Entire system state declared in Git
- Kubernetes manifests describe desired state
- No imperative commands (kubectl edit, etc.)

### 2. Versioned and Immutable
- All changes go through Git
- Every change is versioned and auditable
- Git history provides complete change timeline

### 3. Pulled Automatically
- Cluster pulls changes from Git
- No push-based deployments to cluster
- Argo CD continuously monitors Git

### 4. Continuously Reconciled
- Argo CD compares actual vs desired state
- Drift is automatically corrected
- Manual changes are reverted

## Argo CD Application Structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-api-prod
spec:
  project: default
  source:
    repoURL: https://github.com/ericwang984/sre-gitops-platform.git
    targetRevision: main
    path: apps/demo-app/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: prod
  syncPolicy:
    automated:
      prune: true      # Remove resources not in Git
      selfHeal: true   # Revert manual changes
```

## Sync Modes

### Manual Sync (Default)
- Changes in Git detected
- Operator waits for approval
- Sync on-demand via UI/CLI

### Automated Sync
- Changes in Git auto-applied
- Continuous monitoring
- Self-healing enabled

### Sync Waves
- Order deployments across multiple apps
- Dependencies deploy first
- Database before application

## Drift Detection

Argo CD continuously monitors cluster state:

```
┌─────────────────────────────────────────────────────────┐
│                    Argo CD Controller                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Every 3 minutes:                                        │
│  1. Compare Git state with cluster state                 │
│  2. Detect drift (manual changes, config changes)         │
│  3. If selfHeal enabled: revert to Git state             │
│  4. Report drift in UI                                    │
└─────────────────────────────────────────────────────────┘
```

## Rollback with GitOps

### Method 1: Git Revert
```bash
git revert <commit>
git push
# Argo CD auto-syncs the revert
```

### Method 2: Argo CD Rollback
```bash
argocd app rollback demo-api-prod
# Reverts to previous synced state
```

### Method 3: Manual Git Reset
```bash
git reset --hard <previous-commit>
git push --force
# Use with caution!
```

## Best Practices

1. **Single Source of Truth**
   - All manifests in Git
   - No manual kubectl applies
   - No helm install commands

2. **Branch Strategy**
   - `main`: Production deployments
   - `dev`: Development deployments
   - Feature branches: Testing

3. **Manifest Organization**
   - Base: Common configuration
   - Overlays: Environment-specific
   - Separate apps from infrastructure

4. **Access Control**
   - Git repo permissions control deployment access
   - Argo CD projects for multi-tenant
   - RBAC for cluster access

5. **Change Validation**
   - Pull request reviews required
   - CI checks before merge
   - Argo CD sync policy controls

## Troubleshooting

### Sync Failed
```bash
# Check sync status
argocd app get demo-api-prod

# Check sync logs
argocd app logs demo-api-prod

# Force sync
argocd app sync demo-api-prod --force
```

### Out of Sync
```bash
# Check for drift
argocd app diff demo-api-prod

# View actual vs desired
argocd app manifest demo-api-prod
```

### Manual Changes Detected
```bash
# Argo CD will auto-revert if selfHeal: true

# To keep manual changes, commit to Git
kubectl get deployment demo-api -n prod -o yaml > deployment.yaml
git add deployment.yaml
git commit -m "Update deployment"
git push
```
