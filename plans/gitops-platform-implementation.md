# Implementation Plan: Production-Ready GitOps Platform on Kubernetes

## Context & Motivation

This portfolio project is designed to demonstrate the full spectrum of DevOps/SRE skills that employers actively seek. The project is deliberately scoped to be implementable in 1-2 weeks while covering enough ground to serve as interview talking points for months.

**Why This Project Works:**

1. **Visibility**: Every component can be shown in an interview - the code, the pipeline, the dashboard, the rollback
2. **Authenticity**: Uses real tools at production scale, not toy examples
3. **Narrative**: Tells a complete story from "developer pushes code" to "SRE responds to incident"
4. **Extensibility**: Each component can be discussed deeply if asked

**Two Repository Architecture:**

| Repository | Purpose | Audience |
|------------|---------|----------|
| `sre-demo-app` | Application code + CI | Shows you understand developer experience |
| `sre-gitops-platform` | Infrastructure + GitOps + Observability | Shows you understand platform engineering |

This separation mirrors real-world practice and demonstrates you understand proper concern boundaries.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Developer Experience                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Git Push ──> GitHub Actions ──> Docker Build ──> Vulnerability Scan       │
│                      │                           │                           │
│                      │                           ▼                           │
│                      │                  Push to GHCR                         │
│                      │                           │                           │
│                      ▼                           ▼                           │
│               Run Tests              Update GitOps Repo (automated)          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Platform Layer                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   GitOps Repo Change ──> Argo CD Detects ──> Auto-Syncs to K8s              │
│                              │                        │                      │
│                              ▼                        ▼                      │
│                    Rolling Deploy              Health Checks Pass            │
│                              │                        │                      │
│                              ▼                        ▼                      │
│                      Prometheus Scrapes ──> Metrics Collected               │
│                              │                        │                      │
│                              ▼                        ▼                      │
│                        Loki Collects ──> Logs Aggregated                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Observability & Response                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Alertmanager Evaluates ──> Threshold Breach? ──> Fire Alert              │
│                                    │                                        │
│                     ┌───────────────┴───────────────┐                       │
│                     ▼                               ▼                       │
│            Grafana Dashboard                   Runbook Consult              │
│            Shows Impact                         Response Steps              │
│                     │                               │                       │
│                     └───────────────┬───────────────┘                       │
│                                     ▼                                        │
│                            Argo CD Rollback                                 │
│                                     │                                        │
│                                     ▼                                        │
│                            Post-Incident Review                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Application Repository (`sre-demo-app`)

### 1.1 FastAPI Application - Detailed Specification

**File:** `app/main.py`

**Why FastAPI?**
- Async/await for better performance under load
- Built-in Pydantic validation (production-ready input handling)
- Automatic OpenAPI documentation (`/docs`, `/redoc`)
- Native Prometheus metrics via `prometheus-fastapi-instrumentator`
- Type hints make code more maintainable

**Endpoints Design:**

```python
# Health endpoints - differentiate between liveness and readiness
GET /health      # Is the process alive? (lightweight)
GET /ready       # Is the process ready to serve traffic? (checks dependencies)

# Metrics - for Prometheus scraping
GET /metrics     # Standard Prometheus format

# Business logic - demonstrates real application concerns
GET /api/orders  # Returns mock orders (JSON response)

# Incident simulation - UNIQUE VALUE: lets you demonstrate incident response
GET /api/slow    # Sleeps for configurable duration (simulates latency)
GET /api/error   # Returns 500 error (simulates failure)
```

**Key Implementation Details:**

```python
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(title="SRE Demo API", version="1.0.0")

# Enable Prometheus metrics
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

@app.get("/health")
async def health():
    """Liveness probe - minimal check"""
    return {"status": "healthy"}

@app.get("/ready")
async def readiness():
    """Readiness probe - could check database, redis, etc."""
    # TODO: Add actual dependency checks when adding downstream services
    return {"status": "ready"}

@app.get("/api/orders")
async def get_orders():
    """Business endpoint returning mock data"""
    return {"orders": [...]}

@app.get("/api/slow")
async def slow_response(seconds: int = 5):
    """Simulates slow response for incident testing"""
    import asyncio
    await asyncio.sleep(seconds)
    return {"message": f"Response took {seconds} seconds"}

@app.get("/api/error")
async def error_response():
    """Simulates error for incident testing"""
    raise HTTPException(status_code=500, detail="Simulated error")
```

**Why These Design Choices:**

| Decision | Reason | Interview Talking Point |
|----------|--------|------------------------|
| Separate `/health` and `/ready` | Kubernetes best practice | Explain when each is used by kubelet |
| Prometheus instrumentator | Automatic metrics for free | Discuss RED method (Rate, Errors, Duration) |
| Configurable `/api/slow` | Test different alert thresholds | Show you think about observability |
| Typed responses with Pydantic | Catch bugs at development time | Discuss shift-left testing |

### 1.2 Container Configuration - Production Considerations

**File:** `Dockerfile`

**Multi-Stage Build Strategy:**

```dockerfile
# Stage 1: Builder
FROM python:3.12-slim AS builder
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim
WORKDIR /app

# Non-root user for security
RUN useradd -m -u 1000 appuser

# Copy only what's needed from builder
COPY --from=builder /root/.local /root/.local
COPY app/ .

# Health check that Docker/engine can use
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Run as non-root
USER appuser
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Why These Choices:**

| Practice | Why It Matters | Security Impact |
|----------|----------------|-----------------|
| Multi-stage build | Smaller final image = faster deployments | Reduces attack surface |
| Non-root user | Containers shouldn't run as root | Contains privilege escalation |
| Explicit HEALTHCHECK | Docker can detect unhealthy containers | Enables self-healing |
| Slim base image | Fewer packages = fewer vulnerabilities | Reduces CVE exposure |

### 1.3 CI Pipeline - Security & Quality Gates

**File:** `.github/workflows/ci.yml`

**Pipeline Philosophy:** Fail fast, fail early. Each stage is a gate.

```yaml
name: CI

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

jobs:
  # Gate 1: Code Quality
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: 'pip'  # Cache pip dependencies

      - name: Install dependencies
        run: |
          pip install -r app/requirements.txt
          pip install pytest pytest-cov

      - name: Run tests with coverage
        run: pytest --cov=app --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        # Shows you care about code quality metrics

  # Gate 2: Container Security
  build-and-scan:
    needs: test  # Only run if tests pass
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t demo-api:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: demo-api:${{ github.sha }}
          severity: CRITICAL,HIGH
          exit-code: '1'  # Fail pipeline on CRITICAL/HIGH

      - name: Login to GHCR
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Push to GHCR
        if: github.event_name != 'pull_request'
        run: |
          docker tag demo-api:${{ github.sha }} ghcr.io/${{ github.repository }}:${{ github.sha }}
          docker tag demo-api:${{ github.sha }} ghcr.io/${{ github.repository }}:latest
          docker push ghcr.io/${{ github.repository }}:${{ github.sha }}
          docker push ghcr.io/${{ github.repository }}:latest
```

**Why This Pipeline Structure:**

1. **Tests first**: Don't waste resources building if code is broken
2. **Coverage reporting**: Shows you measure quality
3. **Vulnerability scanning**: Critical for DevOps - shows security awareness
4. **Conditional push**: Don't push on PRs, only on merges to main
5. **Tagged images**: SHA tags for traceability, `latest` for convenience

---

## Phase 2: Platform Repository (`sre-gitops-platform`)

### 2.1 Repository Structure - Organized by Concern

```
sre-gitops-platform/
├── scripts/                    # Operational scripts (not declarative)
│   ├── setup-kind.sh           # Initial cluster creation
│   ├── install-argocd.sh       # Argo CD installation
│   └── verify-cluster.sh       # Health check script
│
├── argocd/                     # GitOps operator configuration
│   ├── applications/           # Application definitions
│   │   ├── demo-app-dev.yaml
│   │   ├── demo-app-prod.yaml
│   │   └── observability.yaml
│   └── projects/               # Argo CD projects (for RBAC)
│       └── demo-project.yaml
│
├── apps/                       # Application manifests
│   └── demo-app/
│       ├── base/               # Base configuration
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── ingress.yaml
│       │   ├── serviceaccount.yaml
│       │   └── kustomization.yaml
│       └── overlays/           # Environment-specific
│           ├── dev/
│           │   ├── kustomization.yaml
│           │   └── patches/
│           │       └── replica-count.yaml
│           └── prod/
│               ├── kustomization.yaml
│               └── patches/
│                   ├── replica-count.yaml
│                   └── resources.yaml
│
├── observability/              # Monitoring stack
│   ├── prometheus/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml     # Scrape configs
│   │   └── alerts.yaml        # Alert rules
│   ├── grafana/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap-dashboards.yaml
│   │   └── datasources/
│   ├── loki/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── alertmanager/
│       ├── deployment.yaml
│       └── configmap.yaml    # Routing config
│
├── base/                       # Base infrastructure (non-app)
│   ├── namespaces.yaml
│   ├── ingress-controller.yaml
│   └── cert-manager.yaml       # Optional: TLS certificates
│
├── runbooks/                   # Operational procedures
│   ├── high-latency.md
│   ├── deployment-failure.md
│   ├── pod-crashloop.md
│   └── rollback.md
│
├── incidents/                  # Post-incident reviews
│   ├── incident-001-high-latency.md
│   ├── incident-002-bad-deployment.md
│   └── incident-003-pod-crashloop.md
│
├── docs/                       # Documentation
│   ├── architecture.md
│   ├── cicd-flow.md
│   ├── gitops-flow.md
│   ├── sre-practices.md
│   └── production-readiness.md
│
└── README.md                   # Project overview
```

### 2.2 Local Cluster Setup - Kind Configuration

**Why Kind Over Minikube?**

| Feature | Kind | Minikube |
|---------|------|----------|
| Startup time | ~30 seconds | ~1-2 minutes |
| Docker-in-Docker | Yes | No |
| Multi-node clusters | Easy | Complex |
| Resource usage | Lower | Higher |
| CI/CD friendly | Yes | Less so |

**File:** `scripts/setup-kind.sh`

```bash
#!/bin/bash
set -e

CLUSTER_NAME="${CLUSTER_NAME:-sre-demo}"

echo "Creating kind cluster: $CLUSTER_NAME"

# Create cluster with extra port mappings for ingress
cat <<EOF | kind create cluster --name $CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v1.29.0
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  image: kindest/node:v1.29.0
- role: worker
  image: kindest/node:v1.29.0
EOF

echo "Cluster created. Waiting for nodes to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=5m

echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/kind/deploy.yaml

echo "Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=5m

echo "Creating namespaces..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

echo "Cluster setup complete!"
echo "Access the cluster via: kubectl get nodes"
```

**Why This Configuration:**

1. **Multi-node**: Demonstrates multi-pod scheduling
2. **Port mappings**: Allows ingress to work on localhost:80/443
3. **Specific version**: Pin Kubernetes version (reproducibility)
4. **Wait conditions**: Don't proceed until components are ready (defensive)

### 2.3 Kubernetes Manifests - Production Patterns

**File:** `apps/demo-app/base/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-api
  labels:
    app: demo-api
    version: v1
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # One extra pod during rollout
      maxUnavailable: 0  # Never reduce below replica count
  selector:
    matchLabels:
      app: demo-api
  template:
    metadata:
      labels:
        app: demo-api
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: demo-api
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: demo-api
        image: ghcr.io/ericwang984/sre-demo-app:latest
        ports:
        - name: http
          containerPort: 8000
          protocol: TCP

        # Readiness: Is this pod ready to receive traffic?
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3

        # Liveness: Should this pod be restarted?
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 15
          periodSeconds: 20
          timeoutSeconds: 3
          failureThreshold: 3

        # Resource management
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "256Mi"

        # Graceful shutdown
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]

        # Security
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL

      # Graceful termination
      terminationGracePeriodSeconds: 30

      # Distribute pods across nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - demo-api
              topologyKey: kubernetes.io/hostname
```

**Key Production Concepts Demonstrated:**

| Concept | Why It Matters | Interview Question It Answers |
|---------|----------------|-------------------------------|
| `maxUnavailable: 0` | Zero-downtime deployments | "How do you deploy without downtime?" |
| Separate readiness/liveness | Prevents cascade failures | "Why have both probes?" |
| Resource requests/limits | Prevents noisy neighbor | "How do you handle resource contention?" |
| `preStop` hook | Graceful connection drain | "How do you handle in-flight requests during termination?" |
| Pod anti-affinity | High availability across nodes | "How do you ensure HA?" |
| `readOnlyRootFilesystem` | Security hardening | "How do you secure your containers?" |
| Prometheus annotations | Service discovery | "How does Prometheus find your pods?" |

**File:** `apps/demo-app/base/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-api
  labels:
    app: demo-api
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: demo-api
```

**File:** `apps/demo-app/base/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-api
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: demo-api.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: demo-api
            port:
              number: 80
```

### 2.4 Environment-Specific Configuration

**File:** `apps/demo-app/overlays/dev/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base

patches:
  - path: patches/replica-count.yaml
```

**File:** `apps/demo-app/overlays/dev/patches/replica-count.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-api
spec:
  replicas: 2
```

**File:** `apps/demo-app/overlays/prod/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: prod

resources:
  - ../../base

patches:
  - path: patches/replica-count.yaml
  - path: patches/resources.yaml

images:
  - name: ghcr.io/ericwang984/sre-demo-app
    newTag: v1.0.0  # Pin specific version in prod
```

**File:** `apps/demo-app/overlays/prod/patches/replica-count.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-api
spec:
  replicas: 3
```

**File:** `apps/demo-app/overlays/prod/patches/resources.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-api
spec:
  template:
    spec:
      containers:
      - name: demo-api
        resources:
          requests:
            cpu: "200m"    # Higher for prod
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "512Mi"
```

**Why This Structure:**

1. **Base + Overlays**: DRY principle - define once, override per environment
2. **Namespace per environment**: Clear separation, easier RBAC
3. **Image pinning in prod**: Control exactly what runs in production
4. **Different resources**: Dev gets less, prod gets more (cost optimization)

### 2.5 Argo CD Configuration

**File:** `argocd/applications/demo-app-prod.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-api-prod
  namespace: argocd
  labels:
    environment: prod
    app: demo-api
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
      prune: true      # Delete resources removed from Git
      selfHeal: true   # Revert manual changes
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**GitOps Flow Diagram:**

```
┌─────────────┐
│   Developer │
└──────┬──────┘
       │ git commit
       ▼
┌─────────────┐     ┌─────────────┐
 │ Git Push   │────>│ GitHub Repo │
 └────────────┘     └──────┬──────┘
                           │ webhook/refresh
                           ▼
                    ┌─────────────┐
                    │  Argo CD    │
                    │  Controller │
                    └──────┬──────┘
                           │ detects drift
                           ▼
                    ┌─────────────┐
                    │  Kubernetes │
                    │    Cluster  │
                    └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   Pods      │
                    │  Running    │
                    └─────────────┘
```

### 2.6 Observability Stack - Complete Monitoring

**Prometheus Configuration:**

**File:** `observability/prometheus/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
    # Kubernetes service discovery
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__

    # Scrape Kubernetes nodes
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
```

**Alert Rules:**

**File:** `observability/prometheus/alerts.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
data:
  alerts.yml: |
    groups:
    - name: demo-api-alerts
      interval: 30s
      rules:
      # Error rate alert - RED method (Errors)
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{namespace="prod",status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total{namespace="prod"}[5m])) > 0.05
        for: 5m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High 5xx error rate on {{ $labels.job }}"
          description: "Error rate is {{ $value | humanizePercentage }} for the last 5 minutes."
          runbook: "https://github.com/ericwang984/sre-gitops-platform/runbooks/high-error-rate.md"

      # Latency alert - RED method (Duration)
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{namespace="prod"}[5m])) by (le)
          ) > 1
        for: 5m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High p95 latency on {{ $labels.job }}"
          description: "p95 latency is {{ $value }}s for the last 5 minutes."

      # Pod health alert
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total{namespace="prod"}[15m]) > 0
        for: 5m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Pod {{ $labels.pod }} is crash looping"
          description: "Pod has restarted {{ $value }} times in the last 15 minutes."

      # Deployment health
      - alert: DeploymentRolloutFailed
        expr: |
          kube_deployment_status_replicas_available{namespace="prod"}
          <
          kube_deployment_spec_replicas{namespace="prod"}
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Deployment {{ $labels.deployment }} not fully available"
          description: "Only {{ $value }}/{{ $labels.deployment }} replicas are ready."
```

**Grafana Dashboards:**

Create three key dashboards:

1. **Application Overview**:
   - Request rate (requests/second)
   - Error rate (% 5xx)
   - Latency (p50, p95, p99)
   - CPU/Memory usage

2. **Kubernetes Cluster Health**:
   - Node status
   - Pod distribution
   - Resource utilization
   - Network I/O

3. **Deployment Dashboard**:
   - Deployment history
   - Rollback count
   - Pod restart trends
   - Image tag timeline

---

## Phase 3: Documentation & Runbooks

### 3.1 Runbook Template

Each runbook follows this structure:

**File:** `runbooks/high-latency.md`

```markdown
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
2024-XX-XX by <your-name>
```

### 3.2 Incident Report Template

**File:** `incidents/incident-001-high-latency.md`

```markdown
# Incident 001: High Latency After Deployment v1.2.0

## Date
2024-XX-XX

## Duration
12 minutes (10:03 - 10:15 UTC)

## Severity
Medium - Degraded performance, no data loss

## Summary
After deploying version v1.2.0, p95 latency increased from 120ms to 1.8s.
The issue was traced to an inefficient database query introduced in the new version.

## Impact
- API requests were slower for approximately 12 minutes
- No data loss occurred
- Error rate remained below 1%
- User-facing: Slower page loads, some timeout errors

## Timeline

| Time | Event |
|------|--------|
| 10:00 | Deployment started through Argo CD |
| 10:02 | Deployment completed, new pods healthy |
| 10:03 | p95 latency alert triggered (1.2s) |
| 10:05 | On-call engineer acknowledged alert |
| 10:06 | Checked Grafana dashboard - confirmed latency spike |
| 10:07 | Checked logs - no errors, just slow responses |
| 10:08 | Checked recent deployment - identified v1.2.0 |
| 10:09 | Decided to rollback to v1.1.0 |
| 10:10 | Rollback initiated via Argo CD |
| 10:12 | Rollback completed |
| 10:15 | Latency returned to normal (~120ms) |

## Root Cause

The new version (v1.2.0) introduced a change in `/api/orders` that added an
additional database query without proper indexing. The N+1 query problem caused
exponential database load as order count increased.

```python
# Problematic code in v1.2.0
for order in orders:
    order.items = db.get_items(order.id)  # N+1 query problem
```

## What Went Well

- Alert fired quickly (within 1 minute of threshold breach)
- Grafana dashboard clearly showed the latency spike
- Argo CD rollback completed smoothly
- No data loss or corruption
- Incident timeline was well-documented

## What Could Be Improved

1. **Pre-deployment testing**: No performance test for `/api/orders`
   - Action: Add load test to CI pipeline for all endpoints

2. **Database query review**: No code review focus on query efficiency
   - Action: Add query plan review to PR checklist

3. **Canary deployment**: Full rollout caught everyone at once
   - Action: Implement canary deployments before full rollout

4. **Database monitoring**: No database-specific metrics/alerts
   - Action: Add PostgreSQL slow query monitoring

## Action Items

| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| Add load test for `/api/orders` | <name> | 2024-XX-XX | Open |
| Fix N+1 query in code | <name> | 2024-XX-XX | Open |
| Add database query monitoring | <name> | 2024-XX-XX | Open |
| Implement canary deployments | <name> | 2024-XX-XX | Open |
| Update runbook with this pattern | <name> | 2024-XX-XX | Open |

## Related Documents
- [Runbook: High Latency](../runbooks/high-latency.md)
- [Grafana Dashboard: Application Metrics](http://localhost:3000/d/app-metrics)

## Tags
`latency`, `deployment`, `rollback`, `database`, `n+1-query`
```

### 3.3 Production Readiness Checklist

**File:** `docs/production-readiness.md`

```markdown
# Production Readiness Checklist

Use this checklist before promoting to production.

## Deployment Readiness

- [ ] Health checks configured (`/health` and `/ready`)
- [ ] Resource requests and limits defined
- [ ] Rolling update configured with `maxUnavailable: 0`
- [ ] Graceful shutdown configured (`preStop` hook)
- [ ] Termination grace period set appropriately
- [ ] Image tag pinned (not using `:latest`)
- [ ] Probes configured with appropriate thresholds
- [ ] Startup time understood and documented

## Reliability

- [ ] Replicas >= 2 for high availability
- [ ] Pod Disruption Budget configured (if using cluster autoscaler)
- [ ] Horizontal Pod Autoscaler configured (optional)
- [ ] Liveness and readiness probes tested
- [ ] Dependency failure handling implemented
- [ ] Circuit breakers for downstream calls (if applicable)

## Security

- [ ] Container image scanned (Trivy/other)
- [ ] No CRITICAL vulnerabilities in image
- [ ] Secrets not committed to Git
- [ ] RBAC configured with least privilege
- [ ] Network policies defined (if applicable)
- [ ] Non-root container user
- [ ] Read-only root filesystem
- [ ] Drop all capabilities
- [ ] TLS enabled for external endpoints

## Observability

- [ ] Metrics exposed at `/metrics`
- [ ] Structured logging implemented
- [ ] Log aggregation configured (Loki)
- [ ] Grafana dashboards created
- [ ] Alerts configured and tested
- [ ] SLOs defined and documented
- [ ] SLIs measured and dashboarded
- [ ] Runbooks written for known failure modes

## Performance

- [ ] Load tests completed
- [ ] Performance baselines established
- [ ] Database queries optimized
- [ ] Caching strategy defined (if applicable)
- [ ] CDN configured for static assets (if applicable)

## Operational

- [ ] Deployment procedure documented
- [ ] Rollback procedure tested
- [ ] On-call rotation defined
- [ ] Escalation path documented
- [ ] Incident response runbooks available
- [ ] Post-incident process defined
- [ ] Architecture diagrams up to date

## Compliance

- [ ] Data retention policy defined
- [ ] PII handling documented (if applicable)
- [ ] Audit logging enabled
- [ ] Backup/restore procedure tested

## Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| Tech Lead | | | |
| SRE | | | |
| Security | | | |
```

---

## Phase 4: Implementation Order (Parallel Approach)

### Step 1: Foundation (Day 1)

**Goals:** Set up both repositories and local development environment.

**App Repository (`sre-demo-app/`):**
```
1. Create GitHub repository
2. Initialize Python project
   ├── app/
   │   ├── __init__.py
   │   ├── main.py
   │   └── requirements.txt
   ├── tests/
   │   ├── __init__.py
   │   └── test_main.py
   └── Dockerfile
3. Implement basic FastAPI app
4. Run locally: uvicorn app.main:app --reload
```

**Platform Repository (`sre-gitops-platform/`):**
```
1. Create GitHub repository
2. Set up directory structure
3. Create kind cluster: ./scripts/setup-kind.sh
4. Verify: kubectl get nodes
```

### Step 2: Application Development (Day 1-2)

**Goals:** Complete the application with all endpoints and tests.

```
sre-demo-app/
├── app/
│   ├── main.py           # FastAPI app with all endpoints
│   └── requirements.txt  # fastapi, uvicorn, prometheus-client
├── tests/
│   └── test_main.py      # Unit tests for each endpoint
├── Dockerfile            # Multi-stage build
└── .github/
    └── workflows/
        └── ci.yml        # Test, build, scan pipeline

Checkpoints:
□ All endpoints work locally
□ Tests pass: pytest
□ Docker build works: docker build -t demo-api .
□ Container runs: docker run -p 8000:8000 demo-api
□ /metrics endpoint returns Prometheus format
```

### Step 3: Kubernetes Manifests (Day 2-3)

**Goals:** Create all Kubernetes resources with Kustomize.

```
sre-gitops-platform/
├── apps/demo-app/base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── serviceaccount.yaml
│   └── kustomization.yaml
└── apps/demo-app/overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patches/replica-count.yaml
    └── prod/
        ├── kustomization.yaml
        └── patches/

Checkpoints:
□ kustomize build apps/demo-app/overlays/dev works
□ Can apply to cluster: kubectl apply -k apps/demo-app/overlays/dev
□ Pods are running: kubectl get pods -n dev
□ Service is accessible: kubectl get svc -n dev
□ Ingress works: curl -H "Host: demo-api.local" http://localhost/api/orders
```

### Step 4: Argo CD Setup (Day 3)

**Goals:** Install Argo CD and configure GitOps.

```
1. Install Argo CD
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

2. Access Argo CD UI
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Login with username: admin, password: (get from secret)

3. Create Application manifests
   argocd/applications/demo-app-dev.yaml
   argocd/applications/demo-app-prod.yaml

4. Apply applications
   kubectl apply -f argocd/applications/

Checkpoints:
□ Argo CD UI accessible at localhost:8080
□ Application shows "Healthy" and "Synced"
□ Changes to Git auto-sync to cluster
□ Manual cluster changes are reverted (self-healing)
```

### Step 5: CI/CD Integration (Day 3-4)

**Goals:** Connect GitHub Actions to the deployment flow.

```
1. Complete GitHub Actions workflow
   - Tests run on every push
   - Docker image builds
   - Trivy scans for vulnerabilities
   - Image pushes to GHCR on main branch

2. (Optional) Update GitOps repo on new image
   - Add step to update image tag in platform repo
   - Uses yq or similar tool

3. Test full flow
   git push -> CI runs -> image pushes -> (optional) GitOps updates -> Argo CD syncs

Checkpoints:
□ Full pipeline runs successfully on push
□ Vulnerability scan fails on bad images
□ Image appears in GitHub Container Registry
□ Argo CD detects and syncs new image (if auto-update configured)
```

### Step 6: Observability (Day 4-6)

**Goals:** Deploy complete monitoring stack.

```
Day 4: Prometheus
1. Install Prometheus
2. Configure scraping
3. Verify metrics collection
   kubectl port-forward -n observability svc/prometheus 9090:9090
   # Query: up{job="kubernetes-pods"}

Day 5: Grafana
1. Install Grafana
2. Configure Prometheus datasource
3. Create dashboards
   - Application overview
   - Cluster health
   kubectl port-forward -n observability svc/grafana 3000:3000

Day 6: Loki & Alertmanager
1. Install Loki
2. Install Promtail
3. Configure Alertmanager
4. Create alert rules
5. Test alerts (trigger /api/slow)

Checkpoints:
□ Prometheus scrapes application metrics
□ Grafana dashboards display data
□ Logs appear in Loki
□ Alerts fire when thresholds breached
□ Alertmanager can route alerts
```

### Step 7: Documentation (Day 6-8)

**Goals:** Complete all documentation.

```
1. README.md
   - Project overview
   - Architecture diagram
   - Quick start guide
   - Screenshots

2. Runbooks (4 files)
   - high-latency.md
   - deployment-failure.md
   - pod-crashloop.md
   - rollback.md

3. Incidents (3 example reports)
   - incident-001-high-latency.md
   - incident-002-bad-deployment.md
   - incident-003-pod-crashloop.md

4. Docs
   - architecture.md
   - cicd-flow.md
   - gitops-flow.md
   - sre-practices.md
   - production-readiness.md

Checkpoints:
□ README renders well on GitHub
□ All runbooks are consistent
□ Incident reports tell a complete story
□ Screenshots are clear and readable
```

### Step 8: Incident Simulation (Day 8)

**Goals:** Test the complete incident response flow.

```
Simulation 1: High Latency
1. Call /api/slow?seconds=10 multiple times
2. Watch for HighLatency alert
3. Follow runbook steps
4. Document as incident-001

Simulation 2: Bad Deployment
1. Deploy broken version
2. Watch for error rate increase
3. Rollback via Argo CD
4. Document as incident-002

Simulation 3: Pod CrashLoop
1. Introduce configuration error
2. Watch for PodCrashLooping alert
3. Fix configuration
4. Document as incident-003

Checkpoints:
□ All alerts fire as expected
□ Runbooks provide correct guidance
□ Rollback works smoothly
□ Incident reports are comprehensive
□ Screenshots captured for portfolio
```

---

## Phase 5: Verification & Testing

### End-to-End Test Checklist

**Application Layer:**
- [ ] App builds and runs locally
- [ ] All endpoints return correct responses
- [ ] /metrics endpoint returns Prometheus format
- [ ] Container can be built from Dockerfile
- [ ] Health checks work correctly

**CI/CD Layer:**
- [ ] Tests run on every push
- [ ] Docker image builds successfully
- [ ] Trivy scan runs and fails on vulnerabilities
- [ ] Image pushes to GHCR
- [ ] Pipeline completes in reasonable time

**GitOps Layer:**
- [ ] Argo CD installs and syncs application
- [ ] Git changes trigger automatic sync
- [ ] Manual cluster changes are reverted
- [ ] Rollback works via Argo CD
- [ ] Application history is tracked

**Kubernetes Layer:**
- [ ] Pods are running and healthy
- [ ] Service routes traffic correctly
- [ ] Ingress routes external traffic
- [ ] Health probes pass
- [ ] Pods distribute across nodes
- [ ] Resource limits are respected

**Observability Layer:**
- [ ] Prometheus scrapes application metrics
- [ ] Grafana dashboards display data
- [ ] Logs appear in Loki
- [ ] Alerts fire when thresholds met
- [ ] Alertmanager can route alerts

**Operational Layer:**
- [ ] Runbooks are accurate
- [ ] Commands in runbooks work
- [ ] Rollback procedures work
- [ ] Incident reports tell clear stories

---

## Interview Preparation Guide

### Key Talking Points

When asked about this project, be ready to discuss:

#### Technical Depth

| Component | Deep Dive Topics |
|-----------|------------------|
| GitOps | Declarative vs imperative, drift detection, self-healing |
| Kubernetes | Pod lifecycle, probes, resource management, scheduling |
| Argo CD | ApplicationSets, Projects, sync waves, resource hooks |
| Prometheus | Scrape configs, recording rules, alerting rules, query optimization |
| Grafana | Dashboard JSON, variables, annotations, provisioning |

#### Design Decisions

Be prepared to explain:

1. **Why two repositories?**
   - Separation of concerns
   - Different release cadences
   - Different access controls
   - Mirrors real-world practice

2. **Why Kustomize over Helm?**
   - Native Kubernetes (no template language)
   - Git-friendly (plain YAML)
   - Easier to debug
   - Works well with Argo CD

3. **Why Prometheus vs other monitoring?**
   - Industry standard for Kubernetes
   - Rich ecosystem
   - Powerful query language
   - Kubernetes-native service discovery

4. **What's missing and why?**
   - No service mesh (overkill for single service)
   - No canary deployment (Flagger adds complexity)
   - No SLO tracking (would need additional tooling)
   - No distributed tracing (single service has no distributed calls)

#### Demonstrated Skills

| Category | Skills | Evidence |
|----------|--------|----------|
| Infrastructure | Kubernetes, Docker, Kind | All manifests work locally |
| CI/CD | GitHub Actions, Trivy | Pipeline passes tests and scans |
| GitOps | Argo CD, Kustomize | Auto-sync working |
| Observability | Prometheus, Grafana, Loki | Dashboards and alerts |
| SRE Practices | Runbooks, incidents, SLOs | Documentation complete |
| Security | Image scanning, RBAC, non-root | Security checklist complete |

### Common Interview Questions

**Q: Tell me about a challenging incident in this project.**

A: Describe Incident 001 (high latency after deployment). Explain:
- The symptom (latency spike)
- How you detected it (alert fired)
- Your investigation process (checked Grafana, logs, recent deploys)
- The resolution (rollback via Argo CD)
- The post-incident actions (added load tests, fixed N+1 query)

**Q: How would you scale this to 100 services?**

A: Discuss:
- Service mesh for traffic management
- Centralized policy enforcement (OPA/Gatekeeper)
- Multi-cluster Argo CD with ApplicationSets
- Automated SLO tracking and error budgets
- On-call rotation and paging (PagerDuty)
- Service catalog (Backstage)

**Q: What would you add if you had another week?**

A: Prioritize by value:
1. Service mesh (mTLS, traffic splitting)
2. Automated canary deployments (Flagger)
3. SLO tracking and error budget automation
4. Distributed tracing (Tempo/Jaeger)
5. Secret management (External Secrets Operator)
6. CI/CD automated GitOps repo updates

**Q: What's your testing strategy?**

A: Explain:
- Unit tests for business logic
- Integration tests for API contracts
- Load tests for performance baselines
- Chaos tests for resilience (use LitmusChaos)
- Canary tests for production validation

---

## Notes & Considerations

### Cost Optimization

For local development, this project is free. For cloud deployment:

| Component | Monthly Cost (est.) | Notes |
|-----------|---------------------|-------|
| EKS cluster | $72/month | Minimum 2 nodes ($0.10/hour each) |
| Load Balancer | $20/month | AWS ALB |
| EBS storage | $10/month | 20 GB for Prometheus/Grafana |
| Data transfer | Variable | Depends on traffic |

**Optimization tips:**
- Use spot instances for worker nodes
- Scale down to zero when not in use
- Use local development most of the time
- Consider using k3s or minikube for cheaper testing

### Performance Considerations

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Pod startup time | < 30s | `kubectl get pods -w` |
| Memory per pod | < 256Mi | `kubectl top pods` |
| CPU per pod | < 500m | `kubectl top pods` |
| Request latency | p95 < 500ms | Prometheus query |
| Error rate | < 0.1% | Prometheus query |

### Security Hardening

Beyond the basics:
- Implement pod security standards
- Use NetworkPolicy to restrict traffic
- Enable audit logging
- Rotate secrets regularly
- Implement admission controllers
- Use image signing (cosign)
- Regular security scans

### Future Enhancements

When you have time:
1. **Service Mesh**: Add Istio or Linkerd for mTLS and traffic management
2. **Canary Deployments**: Use Flagger for automated canary analysis
3. **SLO Automation**: Implement error budget tracking and automated rollback
4. **Chaos Engineering**: Add LitmusChaos for fault injection tests
5. **Secrets Management**: Integrate External Secrets Operator
6. **Multi-cluster**: Deploy to multiple clusters for true DR
7. **Service Catalog**: Add Backstage for developer portal
8. **Policy as Code**: Add OPA/Gatekeeper for policy enforcement

---

## Getting Started Commands

```bash
# Install prerequisites
brew install kind kubectl docker

# Clone repositories
git clone git@github.com:ericwang984/sre-demo-app.git
git clone git@github.com:ericwang984/sre-gitops-platform.git

# Create cluster
cd sre-gitops-platform
./scripts/setup-kind.sh

# Verify cluster
kubectl get nodes
kubectl get pods -A

# Install Argo CD
./scripts/install-argocd.sh

# Access Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Default credentials: admin / (get from secret)
argocd admin initial-password -n argocd

# Deploy application
kubectl apply -f argocd/applications/

# Watch Argo CD sync
argocd app get demo-api-dev --watch

# Access application
kubectl port-forward -n dev svc/demo-api 8080:80
curl http://localhost:8080/health

# Trigger incident
curl http://localhost:8080/api/slow?seconds=10
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 20.10+ | Build and run containers |
| kubectl | 1.29+ | Interact with Kubernetes |
| kind | 0.20+ | Local Kubernetes cluster |
| Python | 3.12+ | Application runtime |
| GitHub account | - | CI/CD and container registry |

### Install Script (macOS)

```bash
#!/bin/bash
# Install all prerequisites on macOS

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install tools
brew install docker kind kubectl python@3.12

# Verify installations
docker --version
kind version
kubectl version --client
python3 --version

echo "All prerequisites installed!"
```

---

## Time Estimate Summary

| Phase | Tasks | Time |
|-------|-------|------|
| 1 | Repository setup, basic app | 4 hours |
| 2 | Complete app, tests, Dockerfile | 6 hours |
| 3 | Kubernetes manifests, Kustomize | 6 hours |
| 4 | Argo CD setup and configuration | 4 hours |
| 5 | CI/CD pipeline | 4 hours |
| 6 | Observability stack | 12 hours |
| 7 | Documentation and runbooks | 10 hours |
| 8 | Incident simulations | 4 hours |
| **Total** | | **~50 hours (6-8 days)** |

---

## Success Criteria

You'll know this project is successful when:

1. **You can demo it end-to-end in 10 minutes**
2. **You can answer "why" for every design decision**
3. **You can trace a change from git push to production deployment**
4. **You can respond to an incident using your runbooks**
5. **You can explain the trade-offs of your technical choices**

Good luck with the build!
