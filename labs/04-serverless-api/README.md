# Lab 04 — The serverless API

Every previous lab billed by the hour whether or not anyone used it. This one charges nothing
until a request arrives, and that single difference reshapes every decision in it.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

Nine resources, no network:

- An **HTTP API** (not a REST API) with a `$default` route
- A **Python 3.12 Lambda** at 256 MB, code inline in the template
- A **DynamoDB table** with a composite key and on-demand billing
- An **execution role** granting four DynamoDB actions on one table ARN
- A **resource policy** letting API Gateway invoke the function
- A **log group declared explicitly** with one-day retention

**No VPC. No subnets. No security groups. No instances. No NAT gateway.** The components are
connected by IAM permissions rather than by routes — which is why there is nothing here to
misconfigure at the network layer.

## Exam domains

| Domain | Weight | What this lab covers |
|---|---|---|
| D3 — Design High-Performing Architectures | 24% | Event-driven compute, cold starts, scaling with no capacity setting, Query vs Scan |
| D4 — Design Cost-Optimized Architectures | 20% | Per-request billing, on-demand vs provisioned, HTTP vs REST API, log retention |
| D1 — Design Secure Architectures | 30% | Execution roles, resource policies, least privilege scoped to one ARN |

## The three ideas worth keeping

1. **Idle cost is genuinely zero.** This is why serverless dominates exam questions containing
   *unpredictable*, *spiky*, *intermittent* or *infrequent*. The corollary matters too: at
   sustained high volume, EC2 and provisioned capacity become cheaper again.
2. **Query reads one partition; Scan reads the whole table** — and bills for everything it reads,
   not for what it returns. Scan on a table that was small when the code was written is a classic
   cost surprise.
3. **Read the `AccessDeniedException`.** It names who, what action, and which resource. The
   failure injection here is worth doing purely to practise that.

## Runbook

```bash
./scripts/verify-clean.sh
./scripts/deploy.sh  labs/04-serverless-api          # preview — free
./scripts/deploy.sh  labs/04-serverless-api --yes    # build — under 2 minutes
#   → work through console-tour.md  (~12 min, mostly in a terminal)
./labs/04-serverless-api/verify/checks.sh
./scripts/teardown.sh labs/04-serverless-api --yes   # under a minute
```

## Cost

**$0.00 per hour idle.** Around **2 cents per 10,000 requests**, all in.

| | Idle $/hr | Per 10k requests |
|---|---|---|
| API Gateway HTTP API | 0.0000 | 0.0100 |
| Lambda | 0.0000 | 0.0021 |
| DynamoDB on-demand | 0.0000 | 0.0080 |
| CloudWatch Logs | 0.0000 | 0.0007 |

For comparison, Lab 01's NAT gateway costs $0.059/hour serving no traffic at all. This stack would
need to handle about **28,000 requests an hour** to match it.

This is the one lab you could safely leave running. It is destroyed anyway, so that
`verify-clean.sh` continues to mean what it says.

## Files

| | |
|---|---|
| `docs/architecture.html` | The architecture document and diagram |
| `docs/body.html` | Content fragment; `scripts/make-doc.py` wraps it in the house style |
| `infra/template.yaml` | The CloudFormation stack, including the function source |
| `console-tour.md` | Walkthrough, including the IAM failure injection |
| `verify/checks.sh` | Read-only assertions, plus two live calls against the API |
| `exam-notes.md` | Exam-style questions |
| `teardown-report.md` | Generated at teardown |
