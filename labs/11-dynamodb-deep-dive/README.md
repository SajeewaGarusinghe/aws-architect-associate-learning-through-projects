# Lab 11 — DynamoDB deep dive

Lab 04 used DynamoDB as one ingredient in a serverless API. This lab makes it the subject: one
table, two item shapes, a GSI, an LSI, TTL, point-in-time recovery, and a Streams-triggered Lambda
that turns a status change into an audit trail — the mechanism behind replication, search-index
sync, and "notify something when a record changes."

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

Five resources, no network:

- A **DynamoDB table** (`saa-lab-11-orders`) holding both orders and products in one table,
  on-demand billing
- **`gsi1-status-by-time`** — a global secondary index, its own partition and sort key, for
  "every order in a given status" without a Scan
- **`lsi1-by-total`** — a local secondary index, same partition key as the base table, for
  "one customer's orders sorted by total" — must be declared at table creation, unlike a GSI
- **TTL** on `expiresAt` and **point-in-time recovery**, both enabled from the template
- A **Streams-triggered Lambda** that reads `NEW_AND_OLD_IMAGES`, detects a status change, and
  writes an audit item back to the same table — plus the execution role and event source mapping
  that wire it up

**No VPC. No API Gateway. No instances.** The demo is driven straight against the DynamoDB and
Lambda APIs, because the point of this lab is what the database does, not what fronts it.

## Exam domains

| Domain | Weight | What this lab covers |
|---|---|---|
| D1 — Design Secure Architectures | 30% | Scoped IAM for stream reads vs. table writes, why removing one permission fails silently and the other loudly |
| D3 — Design High-Performing Architectures | 24% | Query vs. Scan, GSI vs. LSI, sparse indexes, conditional writes, transactions, Streams as an event source |
| D4 — Design Cost-Optimized Architectures | 20% | On-demand billing, free TTL deletions, the write-capacity cost of a transaction vs. two plain writes |

## The three ideas worth keeping

1. **An LSI is a table-creation-time decision; a GSI is not.** You can add or remove a GSI on a
   live table. You cannot add an LSI after the fact, and a table can have at most five. Reach for
   a GSI unless you specifically need strong consistency or the same partition key as the base
   table.
2. **A condition expression makes "check then write" one atomic call.** `ConditionalCheckFailedException`
   is not an error to work around — it *is* the mechanism, and it's how you implement "don't
   oversell," optimistic locking, and idempotent writes without a lock service.
3. **Streams turn a write into an event without anyone polling.** The consumer sees exactly one
   thing happen (an `INSERT`, `MODIFY`, or `REMOVE`) with both the before and after image, whether
   the write came from your application or from a TTL expiry.

## Runbook

```bash
./scripts/verify-clean.sh
./scripts/preflight.sh labs/11-dynamodb-deep-dive
./scripts/deploy.sh    labs/11-dynamodb-deep-dive          # preview — free
./scripts/deploy.sh    labs/11-dynamodb-deep-dive --yes    # build — under a minute
#   → work through console-tour.md  (~20 min)
./labs/11-dynamodb-deep-dive/verify/checks.sh              # also runs the live demo
./scripts/teardown.sh  labs/11-dynamodb-deep-dive --yes    # under a minute
```

## Cost

**$0.00 per hour idle.** The only components that bill at rest are point-in-time recovery
($0.20/GB-month, prorated by the second — a few cents' worth of table data for the duration of
this lab rounds to nothing) and whatever CloudWatch Logs ingests from the demo.

| | Idle $/hr | Per demo run |
|---|---|---|
| DynamoDB on-demand (table + GSI + LSI) | 0.0000 | ~$0.0001 (a dozen reads and writes) |
| DynamoDB Streams reads | 0.0000 | ~$0.0000 (a few GetRecords calls) |
| Point-in-time recovery | ~0.0000 | Billed per GB stored, negligible at this scale |
| Lambda (stream processor) | 0.0000 | Within the always-free tier |
| CloudWatch Logs | 0.0000 | Negligible |

## Files

| | |
|---|---|
| `docs/architecture.html` | The architecture document and diagram |
| `docs/body.html` | Content fragment; `scripts/make-doc.py` wraps it in the house style |
| `infra/template.yaml` | The CloudFormation stack, including the stream processor's source |
| `console-tour.md` | Walkthrough: conditional writes, a transaction, GSI/LSI queries, Streams, TTL, and the IAM failure injection |
| `verify/checks.sh` | Read-only config assertions, plus a full live demo against the table |
| `exam-notes.md` | Exam-style questions |
| `teardown-report.md` | Generated at teardown |
