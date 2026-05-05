# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GitOps platform portfolio project demonstrating SRE/DevOps best practices. It consists of two repositories:
- `sre-demo-app`: Application code with CI pipeline (separate repository)
- `sre-gitops-platform`: Infrastructure, Kubernetes manifests, Argo CD configuration, and observability stack (this repository)

The platform uses kind (Kubernetes in Docker) for local development, Argo CD for GitOps deployments, Kustomize for configuration management, and Prometheus/Grafana/Loki for observability.

## Setup and Development

### Initial Setup

```bash
# Create local Kubernetes cluster
./scripts/setup-kind.sh

# Install Argo CD
./scripts/install-argocd.sh

# Deploy applications via Argo CD
kubectl apply -f argocd/applications/
```

### Access Services

```bash
# Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# http://localhost:8080 (admin/<password-from-secret>)

# Grafana
kubectl port-forward svc/grafana -n observability 3000:3000
# http://localhost:3000 (admin/admin)

# Prometheus
kubectl port-forward svc/prometheus -n observability 9090:9090
# http://localhost:9090

# Application (dev environment)
kubectl port-forward svc/demo-api -n dev 8080:80
# http://localhost:8080
```

### Test Incident Simulation

```bash
# Trigger high latency
curl http://localhost:8080/api/slow?seconds=10

# Trigger errors
curl http://localhost:8080/api/error
```

## Architecture

### Manifest Organization

Kubernetes manifests use Kustomize with base + overlays pattern:
- `apps/demo-app/base/`: Common deployment, service, ingress, serviceaccount
- `apps/demo-app/overlays/dev/`: Development namespace, 2 replicas, lower resources
- `apps/demo-app/overlays/prod/`: Production namespace, 3 replicas, higher resources, pinned image tags

### Deployment Pattern

All deployments follow production-ready patterns:
- `maxUnavailable: 0` for zero-downtime rolling updates
- Separate liveness (`/health`) and readiness (`/ready`) probes
- Resource requests and limits defined
- `preStop` hook for graceful connection drain
- Pod anti-affinity to distribute across nodes
- Prometheus annotations for service discovery
- Non-root container user with dropped capabilities

### Argo CD Applications

Argo CD Application resources in `argocd/applications/` define:
- Source: Git repo path pointing to Kustomize overlays
- Destination: Kubernetes namespace
- Sync policy: Automated with prune and selfHeal for prod
- Auto-sync creates/updates resources, removes deleted resources, reverts manual changes

## GitOps Workflow

1. Code change pushed to app repository
2. CI pipeline builds and pushes image to GHCR
3. Update image tag in `apps/demo-app/overlays/prod/kustomization.yaml`
4. Argo CD detects change and syncs automatically
5. Rolling deployment with zero downtime

**Rollback methods:**
- Via Argo CD: `argocd app rollback demo-api-prod`
- Via kubectl: `kubectl rollout undo deployment/demo-api -n prod`
- Via Git: Revert commit, Argo CD auto-syncs

## Observability

### Alerting

Prometheus alerts defined in `observability/prometheus/alerts.yaml`:
- HighErrorRate: 5xx rate > 5% for 5 minutes
- HighLatency: p95 > 1 second for 5 minutes
- PodCrashLooping: Restart rate elevated for 15 minutes
- DeploymentRolloutFailed: Replicas unavailable for 10 minutes

Alerts fire on symptoms (user-facing issues) not causes, include runbook links.

### Runbooks

Runbooks in `runbooks/` follow consistent structure:
- Symptoms, First Checks, Useful Commands
- Possible Causes table with likelihood
- Mitigation Steps (scale, rollback, resource changes)
- Rollback procedures (Argo CD preferred, kubectl emergency)
- Post-incident actions

## SRE Practices

### SLIs and SLOs

Service Level Indicators (SLIs) measured:
- Request rate: `http_requests_total` (requests/second)
- Latency: `http_request_duration_seconds_bucket` (p50, p95, p99)
- Errors: 5xx rate percentage
- Availability: uptime percentage

Service Level Objectives (SLOs):
- Latency: p95 < 500ms, p99 < 1000ms
- Error rate: < 0.1% (99.9% success)
- Availability: 99.9% uptime (43 min/month error budget)

### Incident Management

Severity levels:
- SEV-1: Complete outage (15 min response)
- SEV-2: Significant degradation (30 min response)
- SEV-3: Minor issues (1 hour response)

Post-incident reviews in `incidents/` include: summary, impact, timeline, root cause, what went well, what to improve, action items.

### Change Management

Release checklist from `docs/production-readiness.md` must be completed before production deployment, covering: deployment readiness, reliability, security (image scanning), observability, performance, operational procedures.

## Security Practices

- Container images scanned with Trivy (CI pipeline in app repo)
- Non-root container user (runAsUser: 1000)
- Resource limits for DoS prevention
- Drop all capabilities
- readOnlyRootFilesystem (set to false in base for writeable filesystem needs)
- No secrets committed to Git (use external secret management in production)

## Common Commands

```bash
# Check application sync status
argocd app get demo-api-prod

# View application history
argocd app history demo-api-prod

# Check for drift
argocd app diff demo-api-prod

# Force sync
argocd app sync demo-api-prod --force

# Check pod resource usage
kubectl top pods -n prod

# Check application logs
kubectl logs -n prod -l app=demo-api --tail=100 --since=5m

# Describe pod for events
kubectl describe pod -n prod -l app=demo-api

# Scale deployment
kubectl scale deployment demo-api -n prod --replicas=5

# Update resources
kubectl set resources deployment demo-api -n prod --limits=cpu=1000m,memory=512Mi

# Get rollout status
kubectl rollout status deployment/demo-api -n prod
```

## Adding New Applications

1. Create `apps/new-app/base/` with deployment.yaml, service.yaml, ingress.yaml, kustomization.yaml following demo-app patterns
2. Create overlays for dev and prod environments
3. Create ArgoCD Application manifest in `argocd/applications/new-app-prod.yaml`
4. Add Prometheus alerts to `observability/prometheus/alerts.yaml`
5. Create runbook in `runbooks/` for common failure modes
6. Update documentation

## Design Decisions

**Two repositories**: Separates application code from infrastructure, enabling different access controls and release cycles.

**Kustomize over Helm**: Native Kubernetes YAML (no template language), Git-friendly for reviews, works well with Argo CD.

**kind for local development**: Free, fast (~30s startup), multi-node support, production-compatible Kubernetes API.

**Automated sync for prod**: Enables self-healing and immediate deployment, manual sync available for dev if needed.
