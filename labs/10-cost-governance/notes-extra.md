## The traps, condensed

1. **CloudTrail = actions. Config = state. CloudWatch = behaviour.** "Who/when" → CloudTrail.
   "Which resources are / is it compliant" → Config. "How busy/slow/many errors" → CloudWatch.
2. **Single-region trails miss everything elsewhere.** Always multi-region, always include global
   service events.
3. **Data events are the CloudTrail bill.** Management events are free; object-level logging on a
   busy bucket is millions of billable events a day.
4. **FORECASTED budget alerts warn before the spend; ACTUAL warns after.** You want both.
5. **An unconfirmed budget email sends nothing.** The resource exists and the alert never arrives.
6. **SCPs bind the root user.** IAM policies do not — an account admin can edit them.
7. **Config bills per configuration item.** `AllSupported: true` in a busy account is an
   unexpected charge.
8. **Steady predictable load → Savings Plans / RIs. Interruptible → Spot.** Never the reverse.
9. **Cost allocation needs tags, activated in billing.** An untagged resource cannot be attributed.
10. **The audit bucket belongs in a different account** in production — an attacker's first move is
    deleting the trail.

## Reference — which service answers which question

| Question | Service |
|---|---|
| Who deleted this, when, from what IP? | **CloudTrail** |
| Which resources are non-compliant right now? | **AWS Config** |
| How was this resource configured last Tuesday? | **AWS Config** (configuration history) |
| Why is the application slow? | **CloudWatch** metrics and logs |
| Am I about to exceed my budget? | **AWS Budgets** (forecasted) |
| Where is my money going? | **Cost Explorer** + cost allocation tags |
| Am I over-provisioned? | **Compute Optimizer** |
| Any recommendations across five pillars? | **Trusted Advisor** |
| Does this workload have known vulnerabilities? | **Amazon Inspector** |
| Is sensitive data sitting in S3? | **Amazon Macie** |
| Are there active threats in my account? | **Amazon GuardDuty** |

## Reference — EC2 purchasing options

| Option | Discount | Commitment | Use for |
|---|---|---|---|
| On-demand | — | None | Spiky, short-lived, unpredictable |
| **Savings Plans** | up to ~72% | 1 or 3 years, $/hour | Steady usage, flexible across instance families |
| **Reserved Instances** | up to ~72% | 1 or 3 years, specific config | Steady usage, known instance type |
| **Spot** | up to ~90% | None; 2-minute reclaim notice | Interruptible, fault-tolerant, flexible timing |
| Dedicated host | — | Optional | Licensing and compliance isolation, not cost |

Compute Savings Plans are the most flexible — they apply across EC2, Fargate and Lambda.

## Reference — the cost lessons from all ten labs

| Lab | Idle $/hour | The lesson |
|---|---|---|
| 01 — VPC | 0.116 | A NAT gateway is **$43/month** to pass packets nobody sends |
| 02 — ALB + ASG | 0.052 | Removing NAT saved more than the load balancer costs |
| 03 — RDS Multi-AZ | 0.078 | Availability doubles the bill for capacity serving nothing |
| **04 — Serverless** | **0.000** | Per-request billing means idle is genuinely free |
| 05 — Decoupling | 0.000 | Queues and topics bill per request too |
| 06 — S3 + CloudFront | 0.000 | Storage class and cache hit ratio are the levers |
| 07 — IAM | 0.000 | IAM is free, always |
| 08 — DR | 0.0014 | RTO and RPO are bought separately |
| 09 — Caching | 0.028 | A cache is a server; a gateway endpoint replaced a $0.059/hr NAT |
| 10 — Governance | ~0.000 | Config bills per item; data events bill per event |

Cost optimisation on the exam is rarely about smaller instances. It is about noticing **which
components charge by the hour whether or not anyone uses them**.
