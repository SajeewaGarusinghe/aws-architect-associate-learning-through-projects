# Lab 05 — Decoupling with queues

Every previous lab connected components synchronously. This one removes that coupling: the
publisher does not know who is listening, does not wait for them, and is unaffected when one breaks.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

Eleven resources, no EC2 and no VPC:

- An **SNS topic** fanning out to two SQS queues from a single publish
- An **orders queue** with a 60s visibility timeout, consumed by Lambda
- An **audit queue** with a **filter policy** — it only receives `priority = high`
- A **dead-letter queue** receiving anything that fails 3 times, retained 14 days
- A consumer whose timeout (30s) is deliberately **below** the visibility timeout (60s)

## Exam domains

| Domain | Weight | Covered here |
|---|---|---|
| D2 — Design Resilient Architectures | 26% | Buffering, retries, DLQs, surviving consumer outages |
| D3 — Design High-Performing Architectures | 24% | Asynchronous decoupling, fan-out, scaling consumers independently |
| D4 — Design Cost-Optimized Architectures | 20% | Per-request billing, long polling, filtering at the topic |

## The three ideas worth keeping

1. **One queue does not fan out.** Several consumers on one standard queue *split* the messages.
   Each needing every message means SNS → one queue per consumer.
2. **Visibility timeout ≥ function timeout.** Reverse them and the same message is processed twice
   with no error anywhere to show it.
3. **Raising is how a consumer reports failure.** Catching the exception and returning normally
   deletes the message — silent data loss that looks like a healthy queue.

## Runbook

```bash
./scripts/verify-clean.sh
./scripts/preflight.sh labs/05-decoupling
./scripts/deploy.sh  labs/05-decoupling          # preview — free
./scripts/deploy.sh  labs/05-decoupling --yes    # under 2 minutes
#   → console-tour.md  (~12 min)
./labs/05-decoupling/verify/checks.sh
./scripts/teardown.sh labs/05-decoupling --yes
```

## Cost

**$0.00 per hour idle.** About **2 cents per 10,000 messages** across SNS, SQS and Lambda.
