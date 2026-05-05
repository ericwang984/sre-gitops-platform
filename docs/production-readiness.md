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
- [ ] Read-only root filesystem (if applicable)
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
