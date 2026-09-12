# Lab 03 — RDS Multi-AZ and a measured failover

Labs 01 and 02 built stateless things, where anything could be replaced by anything else. A
database cannot. This lab is about what high availability means once you have state that must
survive.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

A `10.40.0.0/16` VPC with an RDS PostgreSQL `db.t3.micro`:

- **Multi-AZ**: a synchronously replicated standby in the second availability zone
- A **DB subnet group** across two private subnets with **no route to the internet**
- **Storage encrypted** at rest, `PubliclyAccessible: false`
- The master password **generated and owned by RDS** in Secrets Manager — it appears nowhere in
  the template, in CloudFormation, or in this repository
- A database security group whose source is the **client's security group**, not a CIDR
- A `t3.micro` client reached through Session Manager, with `dbwatch` — a one-second query loop
  used to measure the failover

## Exam domains

| Domain | Weight | What this lab covers |
|---|---|---|
| D2 — Design Resilient Architectures | 26% | Multi-AZ vs read replicas, synchronous replication, automatic failover, RTO/RPO |
| D1 — Design Secure Architectures | 30% | Managed credentials, encryption at rest, private subnets, SG chaining |
| D4 — Design Cost-Optimized Architectures | 20% | Paying double for availability that serves no traffic |

## The three ideas worth keeping

1. **Multi-AZ is for availability; read replicas are for scale.** The standby serves nothing, adds
   no throughput, and doubles the bill. If a question asks how to reduce load on a busy primary,
   Multi-AZ is never the answer. If it asks how to survive an AZ failure with no data loss, a read
   replica is never the answer.
2. **Failover repoints DNS — it does not move an IP.** The endpoint name is identical before and
   after; only the address behind it changes.
3. **Every failover severs every connection.** Multi-AZ protects your *data*. Only retry logic in
   the client protects the *user experience* — and routine patching triggers this too.

## Runbook

```bash
./scripts/verify-clean.sh
./scripts/deploy.sh  labs/03-rds-multi-az           # preview — free
./scripts/deploy.sh  labs/03-rds-multi-az --yes     # build — 12–15 MINUTES
./scripts/console-links.sh labs/03-rds-multi-az
#   → work through console-tour.md  (~15 min)
./labs/03-rds-multi-az/verify/checks.sh
./scripts/teardown.sh labs/03-rds-multi-az --yes    # ~8 minutes
```

**Timing matters more here than in any other lab.** Deploy is 12–15 minutes and the meter runs
throughout; teardown is another 8. Budget a 40-minute auto-teardown window rather than the usual 30:

```bash
./scripts/auto-teardown.sh labs/03-rds-multi-az 2400
```

## Cost

$0.0785/hour while live. A 35-minute window is **about 4.6 cents** — the most expensive lab so
far, and the only one where creation time is a material part of the bill.

| | |
|---|---|
| RDS `db.t3.micro` Multi-AZ | $0.0520/hr — exactly double the single-AZ rate |
| Storage 20 GB gp3, Multi-AZ | $0.0077/hr — also doubled |
| EC2 client + public IPv4 | $0.0182/hr |
| Secrets Manager | $0.0006/hr |

Left running for a month this stack would cost roughly **$57**.

## Files

| | |
|---|---|
| `docs/architecture.html` | The architecture document and topology diagram |
| `docs/body.html` | Content fragment; `scripts/make-doc.py` wraps it in the house style |
| `infra/template.yaml` | The CloudFormation stack |
| `console-tour.md` | Click-by-click guide, including the failover measurement |
| `verify/checks.sh` | Read-only assertions: live account vs documented design |
| `exam-notes.md` | Exam-style questions |
| `teardown-report.md` | Generated at teardown |
