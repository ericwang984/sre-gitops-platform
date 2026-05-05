# Platform Setup Guide

This guide walks you through setting up the SRE GitOps Platform locally on your machine.

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 20.10+ | Container runtime |
| kubectl | 1.29+ | Kubernetes CLI |
| kind | 0.20+ | Local Kubernetes cluster |
| Python | 3.12+ | For app development |
| GitHub account | - | For GitHub Container Registry |

### Install Prerequisites

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install tools
brew install docker kind kubectl python@3.12

# Verify installations
docker --version
kind version
kubectl version --client
python3 --version
```

---

## Platform Setup

### Step 1: Create Kubernetes Cluster

```bash
cd /path/to/sre-gitops-platform
./scripts/setup-kind.sh
```

**What this does:**
- Creates a 3-node Kubernetes cluster (1 control-plane + 2 workers)
- Installs NGINX Ingress Controller for external traffic
- Creates namespaces: dev, prod, observability
- Labels nodes as `ingress-ready` for ingress controller

**Verify:**
```bash
kubectl get nodes
# Should show 3 nodes: 1 control-plane, 2 workers

kubectl get namespaces
# Should show: dev, prod, observability, default
```

---

### Step 2: Install Argo CD

```bash
./scripts/install-argocd.sh
```

**What this does:**
- Creates `argocd` namespace
- Installs Argo CD controller, CRDs, and UI
- Waits for Argo CD server pod to be ready

**Verify:**
```bash
kubectl get pods -n argocd
# Should show Argo CD pods running
```

---

### Step 3: Access Argo CD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open http://localhost:8080 in your browser.

**Login credentials:**
- Username: `admin`
- Password: Run this command to get it:
  ```bash
  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
  ```

---

### Step 4: Deploy Observability Stack

```bash
# Deploy Prometheus
kubectl apply -f observability/prometheus/

# Deploy Grafana
kubectl apply -f observability/grafana/
```

**Verify observability:**
```bash
kubectl get pods -n observability
# Should see prometheus and grafana pods
```

---

### Step 5: Deploy Argo CD Applications

```bash
kubectl apply -f argocd/applications/
```

This registers applications with Argo CD. You should see them in the Argo CD UI.

---

## Access Services

### Argo CD
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
http://localhost:8080
```

### Grafana
```bash
kubectl port-forward svc/grafana -n observability 3000:3000
http://localhost:3000
Username: admin / Password: admin
```

### Prometheus
```bash
kubectl port-forward svc/prometheus -n observability 9090:9090
http://localhost:9090
```

### Application (once deployed)
```bash
kubectl port-forward svc/demo-api -n dev 8080:80
http://localhost:8080
```

---

## Application Deployment

### Before Deploying

Make sure you have:
1. Built and pushed your application image to GitHub Container Registry
2. Updated the image reference in `apps/demo-app/base/deployment.yaml` or overlays

### Deploy via Argo CD

Once your image is available:

```bash
# Option 1: Update image in manifest
# Edit apps/demo-app/overlays/dev/kustomization.yaml
# Update image tag, then commit and push to Git
git add .
git commit -m "Update image tag"
git push

# Argo CD will auto-sync within 3 minutes
```

```bash
# Option 2: Manual sync in Argo CD CLI
argocd app sync demo-api-dev
```

---

## Cleanup

### Delete Cluster (when done working)

```bash
./scripts/cleanup-kind.sh
```

### Delete All Kind Clusters

```bash
kind delete clusters --all
```

### Clean Up Namespaces (if cluster still exists)

```bash
kubectl delete namespace dev --ignore-not-found=true
kubectl delete namespace prod --ignore-not-found=true
kubectl delete namespace observability --ignore-not-found=true
kubectl delete namespace argocd --ignore-not-found=true
```

---

## Troubleshooting

### Issue: "kind: command not found"
**Solution:** Install kind: `brew install kind`

### Issue: "timed out waiting for ingress controller"
**Solution:**
```bash
# Delete broken ingress
kubectl delete namespace ingress-nginx

# Reinstall
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/kind/deploy.yaml

# Label nodes
kubectl label nodes --all ingress-ready=true
```

### Issue: Argo CD UI won't load
**Solution:** Check password and port-forward:
```bash
# Get password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# Check port is not in use
lsof -i :8080
```

### Issue: Pod stuck in ImagePullBackOff
**Solution:** Check image name and registry access:
```bash
kubectl describe pod <pod-name> -n <namespace>
```

### Issue: Argo CD shows "OutOfSync"
**Solution:** Check for syntax errors in manifests:
```bash
kubectl apply -k apps/demo-app/overlays/dev --dry-run=server
```

---

## Quick Reference Commands

```bash
# Cluster status
kubectl get nodes
kubectl get pods -A

# Argo CD operations
argocd app list
argocd app get demo-api-dev
argocd app sync demo-api-dev
argocd app history demo-api-prod

# Application operations
kubectl get pods -n dev
kubectl logs -n dev -l app=demo-api
kubectl port-forward svc/demo-api -n dev 8080:80

# Rollback
argocd app rollback demo-api-dev
kubectl rollout undo deployment/demo-api -n dev

# Observability
kubectl top nodes
kubectl top pods -A
```

---

## Next Steps After Setup

1. **Build and push your application** (from `sre-demo-app` repository)
2. **Update image references** in manifests to point to your registry
3. **Deploy** via Argo CD
4. **Test endpoints** and verify metrics collection
5. **Simulate incidents** using `/api/slow` and `/api/error` endpoints
6. **Practice rollback** procedures

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Git Repository                        │
│                   (sre-gitops-platform)                    │
│                                                              │
│  ┌────────────┐       ┌──────────────┐       ┌────────────┐ │
│  │   Argo CD   │───────│   K8s Cluster │───────│   Kind     │ │
│  │   Apps      │       │   (kind)       │       │            │ │
│  └────────────┘       └──────────────┘       └────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    Observability                      │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────────────┐  │ │
│  │  │Prometheus│  │ Grafana │  │     Loki        │  │ │
│  │  └─────────┘  └─────────┘  └─────────────────┘  │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

For more details, see:
- [Architecture](docs/architecture.md) - System design and decisions
- [GitOps Flow](docs/gitops-flow.md) - How GitOps works
- [SRE Practices](docs/sre-practices.md) - Operational procedures
