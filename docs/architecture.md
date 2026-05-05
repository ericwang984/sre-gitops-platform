# Architecture

## Overview

This GitOps platform demonstrates production-ready DevOps/SRE practices using:
- Kubernetes for container orchestration
- Argo CD for GitOps deployment
- Prometheus/Grafana for observability
- Kustomize for configuration management

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Developer Workflow                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐      ┌──────────────┐      ┌──────────────┐   │
│  │    Code     │─────>│   GitHub     │─────>│ GitHub       │   │
│  │  Changes    │      │   Repository │      │ Actions (CI) │   │
│  └─────────────┘      └──────────────┘      └──────┬───────┘   │
│                                                  │             │
│                                                  ▼             │
│                                          ┌──────────────┐   │
│                                          │    GHCR      │   │
│                                          │ (Registry)   │   │
│                                          └──────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         GitOps Platform                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐      ┌─────────────┐  │
│  │    GitOps    │─────>│    Argo CD   │─────>│  Kubernetes │  │
│  │     Repo     │      │   Controller │      │   Cluster   │  │
│  └──────────────┘      └──────────────┘      └──────┬──────┘  │
│                                                      │         │
│                                                      ▼         │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                      Applications                         │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────────────────────┐  │ │
│  │  │   dev   │  │   prod  │  │   Observability Stack   │  │ │
│  │  └─────────┘  └─────────┘  │  - Prometheus            │  │ │
│  │                               │  - Grafana               │  │ │
│  │                               │  - Loki                  │  │ │
│  │                               │  - Alertmanager          │  │ │
│  │                               └─────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Observability Flow                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Application ──> Metrics ──> Prometheus ──> Alertmanager ──> Alert│
│       │               │              │                           │
│       │               ▼              ▼                           │
│       Logs          Grafana Dashboards                           │
│       │                                                             │
│       ▼                                                             │
│      Loki                                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Application Layer
- **FastAPI App**: Python web service with health, metrics, and business endpoints
- **Docker**: Container runtime with multi-stage builds
- **GitHub Actions**: CI/CD pipeline for testing and image building

### Platform Layer
- **kind**: Local Kubernetes cluster for development
- **Argo CD**: GitOps operator for continuous deployment
- **Kustomize**: Configuration management for environment-specific settings
- **NGINX Ingress**: Ingress controller for external access

### Observability Layer
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation
- **Alertmanager**: Alert routing and management

## Data Flow

1. **Deployment Flow**
   ```
   Developer push -> GitHub Actions builds image -> Image pushed to GHCR
   -> (Optional) GitOps repo updated -> Argo CD detects change -> K8s deploys
   ```

2. **Monitoring Flow**
   ```
   App exposes /metrics -> Prometheus scrapes -> Alerts evaluated
   -> Grafana displays -> Alertmanager routes alerts
   ```

3. **Incident Response Flow**
   ```
   Alert fires -> On-call notified -> Runbook consulted -> Investigation
   -> Mitigation/Rollback -> Post-incident review
   ```

## Design Decisions

### Two Repository Architecture
- **sre-demo-app**: Application code with CI pipeline
- **sre-gitops-platform**: Infrastructure and manifests
- **Rationale**: Separation of concerns, different access controls, independent release cycles

### Kustomize over Helm
- Native Kubernetes YAML (no template language)
- Git-friendly for reviews and diffs
- Works well with Argo CD
- Easier to debug and understand

### Local Development with kind
- Free and fast
- Supports multi-node clusters
- Docker-in-Docker for easy CI/CD
- Production-compatible Kubernetes API

## Security Considerations

- Non-root container users
- Resource limits for DoS prevention
- Network policies (when applicable)
- RBAC for Kubernetes access
- Image vulnerability scanning
- Secrets management (externalize in production)

## Scaling Considerations

For production scaling to 100+ services:
1. Add service mesh (Istio/Linkerd) for mTLS and traffic management
2. Implement canary deployments (Flagger)
3. Add SLO automation and error budget tracking
4. Deploy multiple clusters for HA/DR
5. Implement service catalog (Backstage)
6. Add policy as code (OPA/Gatekeeper)

## Cost Estimates

| Component | Local | Cloud (Monthly) |
|-----------|-------|-----------------|
| Kubernetes | Free | $72 (EKS: 2 nodes) |
| Load Balancer | N/A | $20 (ALB) |
| Storage | N/A | $10 (20GB) |
| Registry | Free | Included |
| **Total** | **Free** | **~$100** |
