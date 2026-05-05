# CI/CD Flow

## Overview

This project uses GitHub Actions for continuous integration and container building.
The GitOps pattern separates the CI (building) from CD (deploying).

## Pipeline Stages

### 1. Test Stage
```yaml
- Set up Python environment
- Install dependencies
- Run unit tests with pytest
- Generate coverage reports
```

### 2. Build Stage
```yaml
- Build Docker image
- Tag with git SHA
```

### 3. Scan Stage
```yaml
- Run Trivy vulnerability scanner
- Fail on CRITICAL/HIGH severity
```

### 4. Push Stage (main branch only)
```yaml
- Login to GitHub Container Registry
- Push image with SHA tag
- Push image with latest tag
```

### 5. Deploy Stage (optional)
```yaml
- Update GitOps repo with new image tag
- Argo CD detects change and syncs
```

## Flow Diagram

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   Push   │────>│   Test   │────>│  Build   │────>│  Scan    │
│  to Git  │     │   Code   │     │  Image   │     │ for Vulns │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                                                          │
                     ┌─────────────┬────────────────────┘
                     │             │
                     ▼             ▼
              ┌──────────┐   ┌──────────┐
              │   Fail   │   │  Pass    │
              └──────────┘   └────┬─────┘
                                   │
                                   ▼
                            ┌──────────┐
                            │  Push    │
                            │ to GHCR  │
                            └────┬─────┘
                                 │
               ┌─────────────────┴─────────────────┐
               │                                   │
               ▼                                   ▼
        ┌────────────┐                      ┌────────────┐
        │  PR/Merge  │                      │    Main    │
        │            │                      │  Branch    │
        └────────────┘                      └─────┬──────┘
                                                   │
                                                   ▼
                                          ┌─────────────────┐
                                          │ Update GitOps   │
                                          │   (Optional)    │
                                          └────────┬────────┘
                                                   │
                                                   ▼
                                          ┌─────────────────┐
                                          │    Argo CD      │
                                          │   Auto Sync     │
                                          └─────────────────┘
```

## GitHub Actions Workflow

The workflow is defined in `.github/workflows/ci.yml` in the app repository:

```yaml
name: CI

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Set up Python
      - Install dependencies
      - Run tests with coverage

  build-and-scan:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - Checkout code
      - Build Docker image
      - Run Trivy scan
      - (main only) Login to GHCR
      - (main only) Push image
```

## Image Tagging Strategy

| Tag | Purpose | Update Frequency |
|-----|---------|------------------|
| `latest` | Latest stable | Every main branch push |
| `<sha>` | Specific commit | Every push (PR + main) |
| `v1.0.0` | Semantic version | Manual release |

## Security Scanning

Trivy scans for:
- OS package vulnerabilities
- Application dependencies
- Configuration issues

Failure criteria:
- CRITICAL severity: Always fail
- HIGH severity: Fail in production

## Deployment Automation (Optional)

To enable automatic deployment updates, add a step in the CI pipeline:

```yaml
- name: Update GitOps repo
  run: |
    yq -i '.images[0].newTag = "${{ github.sha }}"' \
      path/to/apps/demo-app/overlays/prod/kustomization.yaml
```

This updates the image tag in the GitOps repository, triggering Argo CD sync.

## Manual Deployment

If not using automatic updates:

1. CI completes successfully
2. Note the image SHA from build logs
3. Update `apps/demo-app/overlays/prod/kustomization.yaml`:
   ```yaml
   images:
   - name: ghcr.io/ericwang984/sre-demo-app
     newTag: <sha>
   ```
4. Commit and push to main
5. Argo CD auto-syncs the change

## Best Practices

1. **Always scan images** before pushing to registry
2. **Use specific SHA tags** for production deployments
3. **Never use `latest`** in production manifests
4. **Run tests before building** to fail fast
5. **Keep pipelines fast** with caching and parallel jobs
6. **Monitor pipeline duration** and optimize slow steps
