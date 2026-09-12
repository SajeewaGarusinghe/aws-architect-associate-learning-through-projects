# Lab 08 — Failover and recovery points

Disaster recovery is usually taught as four named strategies and two acronyms. This lab builds the
two mechanisms underneath them: what moves traffic when something dies, and what determines the
data you can get back afterwards.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

- A **Route 53 health check** (30s interval, unhealthy after 2 failures)
- A hosted zone with **PRIMARY and SECONDARY failover records** on one name, TTL 60
- A **versioned S3 bucket** — overwrite and delete become recoverable events
- A **DynamoDB table with point-in-time recovery** — restore to any second in 35 days

The zone is for a domain nobody owns; querying its own nameservers directly is all the lab needs.

## Exam domains

| Domain | Weight | Covered here |
|---|---|---|
| D2 — Design Resilient Architectures | 26% | RTO/RPO, the four DR strategies, failover routing, health checks, backup mechanics |
| D1 — Design Secure Architectures | 30% | Versioning and PITR as protection against error, not just failure |

## The three ideas worth keeping

1. **RTO is downtime; RPO is data loss.** Bought separately — failover routing buys RTO and does
   nothing for RPO.
2. **TTL is a floor on recovery time.** Route 53 can react in 60 seconds and still leave clients on
   a dead endpoint for an hour.
3. **Versioning and PITR are not retroactive.** Enabling them after the mistake recovers nothing.

## Runbook

```bash
./scripts/deploy.sh  labs/08-dr-patterns --yes     # under 2 minutes
#   wait 60–90s for the health check to report Healthy
#   → console-tour.md  (~15 min)
./labs/08-dr-patterns/verify/checks.sh
./scripts/teardown.sh labs/08-dr-patterns --yes
```

## Cost

**~$0.0014/hour** — hosted zone $0.50/month plus health check $0.50/month, prorated. Under two
cents for the lab. Empty the versioned bucket before teardown.
