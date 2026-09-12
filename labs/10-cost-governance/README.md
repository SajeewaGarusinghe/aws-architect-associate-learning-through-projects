# Lab 10 — Who did it, and what it cost

Nine labs have been created and destroyed in this account. This one turns on the services that
would have told you about it, then reads back the record of everything the earlier labs did.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

- A **multi-region CloudTrail trail** with log file validation, writing to an audit bucket
- An **AWS Config recorder** scoped to four resource types, with two managed rules
- A **$5 monthly budget** with both an `ACTUAL` and a `FORECASTED` notification

## Before you deploy

The budget needs an email address, and this repository is **public**:

```bash
cp labs/10-cost-governance/infra/params.example.json labs/10-cost-governance/infra/params.json
# edit params.json — it is gitignored
```

`deploy.sh` picks the file up automatically. **Confirm the subscription from your inbox**, or the
budget will exist, look configured, and silently never alert.

## Exam domains

| Domain | Weight | Covered here |
|---|---|---|
| D1 — Design Secure Architectures | 30% | CloudTrail, log integrity, Config compliance, SCPs |
| D4 — Design Cost-Optimized Architectures | 20% | Budgets, purchasing options, cost allocation tags, Config pricing |

## The three ideas worth keeping

1. **CloudTrail = actions. Config = state. CloudWatch = behaviour.** The exam routinely offers one
   when the question needs another.
2. **Data events are the CloudTrail bill.** Management events are free; object-level logging on a
   busy bucket is millions of billable events a day.
3. **FORECASTED alerts warn before the spend.** `ACTUAL` only tells you afterwards.

## Runbook

```bash
./scripts/deploy.sh  labs/10-cost-governance --yes   # 2–3 minutes
#   → console-tour.md  (~20 min) — read back labs 01–09 in CloudTrail
./labs/10-cost-governance/verify/checks.sh
./scripts/teardown.sh labs/10-cost-governance --yes
```

## Cost

**~1 cent.** CloudTrail management events and budgets are free; Config bills ~$0.003 per
configuration item. Consider recreating the budget standalone afterwards — it is free and it
protects every future lab.
