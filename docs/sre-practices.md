# SRE Practices

## Overview

This project demonstrates core Site Reliability Engineering practices that
distinguish SRE from traditional operations.

## SRE vs Traditional Operations

| Traditional Ops | SRE |
|----------------|-----|
| Reactive fire-fighting | Proactive error budget management |
| Manual operations | Automation and tooling |
| Toil elimination | Engineering focus |
| MTTR focused | SLI/SLO balance |

## SLIs, SLOs, and Error Budgets

### SLIs (Service Level Indicators)
Measured metrics that indicate service health:

```yaml
Request Rate:
  - Metric: http_requests_total
  - Measurement: requests per second

Latency:
  - Metric: http_request_duration_seconds
  - Measurement: p50, p95, p99 percentiles

Errors:
  - Metric: http_requests_total{status=~"5.."}
  - Measurement: error rate percentage

Availability:
  - Metric: up{namespace="prod"}
  - Measurement: percentage of time service is up
```

### SLOs (Service Level Objectives)
Target values for SLIs:

```yaml
Latency SLO:
  - p95 < 500ms
  - p99 < 1000ms

Error Rate SLO:
  - < 0.1% (99.9% success rate)

Availability SLO:
  - 99.9% uptime (43 minutes/month downtime)
```

### Error Budget
The amount of "failure" allowed within the SLO:

```
Error Budget = 1 - Availability SLO

For 99.9% availability:
Error Budget = 0.1% = 43 minutes/month
```

## Incident Management

### Incident Severity Levels

| Severity | Description | Response Time |
|----------|-------------|---------------|
| SEV-1 | Complete service outage | 15 minutes |
| SEV-2 | Significant degradation | 30 minutes |
| SEV-3 | Minor issues | 1 hour |
| SEV-4 | Cosmetic issues | Next business day |

### Incident Response Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Alert      │────>│   Acknowledge │────>│  Investigate  │
│  Fires       │     │   (PagerDuty) │     │   (Grafana)   │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                                  ▼
                                          ┌──────────────┐
                                          │  Mitigate    │
                                          │  (Rollback)   │
                                          └──────┬───────┘
                                                  │
                                                  ▼
                                          ┌──────────────┐
                                          │    Resolve    │
                                          └──────┬───────┘
                                                  │
                                                  ▼
                                          ┌──────────────┐
                                          │   Post-Mortem │
                                          │   (Review)    │
                                          └──────────────┘
```

### Incident Command System (ICS)

Roles during major incidents:
- **Incident Commander**: Coordinates response
- **Operations Lead**: Manages technical resolution
- **Communications Lead**: Manages stakeholder communication
- **Documentation Scribe**: Records timeline and actions

## Monitoring and Alerting

### Alerting Principles

1. **Alert on symptoms, not causes**
   - Bad: "CPU usage high"
   - Good: "p95 latency > 500ms"

2. **Alert only when action is needed**
   - Don't alert for self-healing issues
   - Don't alert for transient blips

3. **Make alerts actionable**
   - Include runbook link
   - Include dashboard link
   - Include relevant labels

### Alert Example

```yaml
- alert: HighErrorRate
  expr: error_rate > 0.01
  for: 5m
  labels:
    severity: warning
    team: platform
  annotations:
    summary: "High error rate detected"
    description: "Error rate is {{ $value }} for the last 5 minutes."
    runbook: "https://github.com/your-repo/runbooks/high-error-rate.md"
    dashboard: "http://grafana/d/app-overview"
```

## Change Management

### Deployment Strategies

1. **Blue-Green**: Two environments, switch traffic instantly
2. **Rolling**: Gradual replacement of old pods
3. **Canary**: Test new version with small traffic
4. **Shadow**: Traffic mirrored to new version (no impact)

### Release Checklist

- [ ] Tests pass in CI
- [ ] Image scanned for vulnerabilities
- [ ] Load tests completed
- [ ] Rollback plan documented
- [ ] On-call team notified
- [ ] Monitoring verified
- [ ] Runbooks updated

## Toil Reduction

Toil is manual, repetitive work that automates:
- Manual deployments → GitOps
- Manual scaling → HPA
- Manual log checking → Alerts and dashboards
- Manual failover → Automated failover

## Capacity Planning

### Steps

1. **Measure current usage**
   ```bash
   kubectl top nodes
   kubectl top pods -A
   ```

2. **Forecast growth**
   - Historical trends
   - Business projections
   - Seasonal patterns

3. **Plan headroom**
   - 50% buffer for normal operations
   - 2x capacity for peak events
   - 3x capacity for disaster recovery

4. **Schedule reviews**
   - Quarterly capacity reviews
   - Monthly trend analysis
   - Weekly anomaly detection

## Post-Incident Review

### Purpose

Not for blame assignment, but for learning:
- What happened?
- Why did it happen?
- What can we improve?

### Sections

1. **Summary**: Brief description
2. **Impact**: User-facing effects
3. **Timeline**: Chronological events
4. **Root Cause**: Why it happened
5. **What Went Well**: Positive aspects
6. **What Can Improve**: Action items
7. **Action Items**: Follow-up tasks

## Continuous Improvement

1. **Blameless Post-Mortems**
   - Focus on systems, not people
   - Encourage honesty
   - Share learnings widely

2. **Error Budget Consumption**
   - Track how much budget used
   - Plan feature freezes when low
   - Prioritize stability over features

3. **Toil Tracking**
   - Measure time spent on manual tasks
   - Set goals for automation
   - Eliminate toil systematically
