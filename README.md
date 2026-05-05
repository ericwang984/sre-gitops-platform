# SRE GitOps Platform

A production-ready GitOps platform demonstrating DevOps/SRE best practices with Kubernetes, Argo CD, and observability tools.

![Architecture](docs/architecture.md)

## Overview

This project implements a complete GitOps workflow for deploying and operating containerized applications on Kubernetes. It demonstrates the full spectrum of SRE practices including:

- **GitOps** with Argo CD for declarative deployments
- **Observability** with Prometheus, Grafana, and Loki
- **Incident Management** with runbooks and post-incident reviews
- **Security** with image scanning and non-root containers
- **High Availability** with rolling updates and health checks

## Architecture

```
Developer Push -> GitHub Actions -> Docker Build -> GHCR
                                             |
                                             v
                                      GitOps Repo Updated
                                             |
                                             v
                                          Argo CD
                                             |
                                             v
                                      Kubernetes Cluster
                                             |
                                             v
                            Prometheus + Grafana + Loki
                                             |
                                             v
                                      Alertmanager
```

## Quick Start

### Prerequisites

- Docker
- kubectl
- kind (Kubernetes in Docker)
- Python 3.12+
- GitHub account

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/ericwang984/sre-gitops-platform.git
   cd sre-gitops-platform
   ```

2. **Create the cluster**
   ```bash
   ./scripts/setup-kind.sh
   ```

3. **Install Argo CD**
   ```bash
   ./scripts/install-argocd.sh
   ```

4. **Deploy the application**
   ```bash
   kubectl apply -f argocd/applications/
   ```

5. **Access Argo CD UI**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Open http://localhost:8080
   # Login: admin / (get password with: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
   ```

## Project Structure

```
sre-gitops-platform/
├── apps/                    # Application manifests
│   └── demo-app/
│       ├── base/           # Base configuration
│       └── overlays/       # Environment-specific
├── argocd/                 # Argo CD configuration
│   └── applications/      # Application definitions
├── observability/          # Monitoring stack
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   └── alertmanager/
├── runbooks/               # Operational procedures
├── incidents/              # Post-incident reviews
├── docs/                   # Documentation
└── scripts/                # Setup scripts
```

## Environments

| Environment | Namespace | Replicas | Resources |
|-------------|-----------|----------|-----------|
| dev | dev | 2 | 100m CPU / 128Mi RAM |
| prod | prod | 3 | 200m CPU / 256Mi RAM |

## Observability

### Access Dashboards

```bash
# Grafana
kubectl port-forward svc/grafana -n observability 3000:3000
# http://localhost:3000
# Username: admin / Password: admin

# Prometheus
kubectl port-forward svc/prometheus -n observability 9090:9090
# http://localhost:9090
```

### Dashboards

- **Application Overview**: Request rate, latency, errors, resource usage
- **Kubernetes Cluster Health**: Node status, pod distribution, resource utilization
- **Deployment Dashboard**: Deployment history, rollback count, pod restarts

### Alerts

- **HighErrorRate**: 5xx error rate exceeds 5%
- **HighLatency**: p95 latency exceeds 1 second
- **PodCrashLooping**: Pod restart rate elevated
- **DeploymentRolloutFailed**: Deployment not fully available

## Runbooks

Operational procedures for common incidents:

- [High Latency](runbooks/high-latency.md)
- [Deployment Failure](runbooks/deployment-failure.md)
- [Pod CrashLoop](runbooks/pod-crashloop.md)
- [Rollback](runbooks/rollback.md)

## Incidents

Post-incident reviews documenting learned lessons:

- [Incident 001: High Latency](incidents/incident-001-high-latency.md)
- [Incident 002: Bad Deployment](incidents/incident-002-bad-deployment.md)
- [Incident 003: Memory Leak](incidents/incident-003-pod-crashloop.md)

## Testing the Application

### Access the Application

```bash
# Port forward to local
kubectl port-forward svc/demo-api -n dev 8080:80

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/metrics
curl http://localhost:8080/api/orders

# Simulate incidents
curl http://localhost:8080/api/slow?seconds=10
curl http://localhost:8080/api/error
```

### Simulate an Incident

1. Trigger high latency:
   ```bash
   curl http://localhost:8080/api/slow?seconds=10
   ```

2. Watch for the HighLatency alert in Prometheus/Alertmanager

3. Follow the runbook: [High Latency](runbooks/high-latency.md)

4. Practice rollback:
   ```bash
   argocd app rollback demo-api-dev
   ```

## Deployment Flow

1. Developer pushes code to `sre-demo-app` repository
2. GitHub Actions runs tests, builds image, scans for vulnerabilities
3. Image pushed to GitHub Container Registry
4. GitOps repository updated with new image tag
5. Argo CD detects change and syncs to Kubernetes
6. Prometheus scrapes new pods' metrics
7. Grafana displays updated dashboards

## Documentation

- [Architecture](docs/architecture.md) - System architecture and design decisions
- [CI/CD Flow](docs/cicd-flow.md) - Pipeline and deployment automation
- [GitOps Flow](docs/gitops-flow.md) - GitOps principles and Argo CD usage
- [SRE Practices](docs/sre-practices.md) - SRE methodologies and practices
- [Production Readiness](docs/production-readiness.md) - Pre-deployment checklist

## Contributing

This is a portfolio project demonstrating SRE/DevOps skills. When extending:

1. Follow existing patterns
2. Update documentation
3. Add tests for new features
4. Update runbooks for new failure modes

## License

MIT License - see LICENSE file for details

## Author

Built as a portfolio project to demonstrate production-ready SRE/DevOps skills.

## Acknowledgments

- [Argo CD](https://argoproj.github.io/argo-cd/)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)
- [Kubernetes](https://kubernetes.io/)
- [FastAPI](https://fastapi.tiangolo.com/)
