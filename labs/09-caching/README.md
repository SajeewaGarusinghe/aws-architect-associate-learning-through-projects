# Lab 09 — Cache-aside, measured

Lab 04 deliberately kept its function out of a VPC. This one puts a function inside one, because it
has the only good reason to: ElastiCache is reachable from nowhere else.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

- **ElastiCache for Redis**, a single `cache.t3.micro` node in private subnets
- A **Lambda inside the VPC** implementing cache-aside, reporting hit/miss and elapsed ms
- A **DynamoDB gateway endpoint** — free, and the only way the function reaches the table
- **No NAT gateway and no `0.0.0.0/0` route** anywhere in the VPC
- Redis reachable only from the function's security group

## Exam domains

| Domain | Weight | Covered here |
|---|---|---|
| D3 — Design High-Performing Architectures | 24% | Caching strategies, TTL, Redis vs Memcached, where caches belong |
| D4 — Design Cost-Optimized Architectures | 20% | Gateway endpoint instead of NAT, a cache billing by the hour |
| D1 — Design Secure Architectures | 30% | VPC-attached Lambda, security group chaining |

## The three ideas worth keeping

1. **Gateway endpoints are free and exist only for S3 and DynamoDB.** Using NAT instead would more
   than triple this lab's cost to do the same work more slowly.
2. **Only put Lambda in a VPC to reach VPC-only resources.** "For security" is wrong — S3, DynamoDB
   and SQS are not in your VPC.
3. **A cache failure must cost latency, not availability.** Cache-aside falls through to the system
   of record; if it cannot, you built a dependency.

## Runbook

```bash
./scripts/verify-clean.sh
./scripts/preflight.sh labs/09-caching
./scripts/deploy.sh  labs/09-caching --yes        # 6–9 minutes
./scripts/auto-teardown.sh labs/09-caching 2100   # 35-minute backstop
#   → console-tour.md  (~20 min)
./labs/09-caching/verify/checks.sh
./scripts/teardown.sh labs/09-caching --yes       # 8–12 minutes (ENIs must detach)
```

## Cost

**$0.028/hour** — the cache node, which bills whether or not anything uses it. Everything else is
per-request. Under a cent for a 20-minute window.
