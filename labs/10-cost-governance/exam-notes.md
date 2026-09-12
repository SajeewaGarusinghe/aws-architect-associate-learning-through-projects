# Exam notes — Lab 10 (Cost and governance)

Twelve SAA-C03-style questions on auditing, compliance and cost control, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** A security team needs to know which IAM user deleted a production S3 bucket last Tuesday, and from what IP address. Which service answers this?

- A. AWS Config
- B. AWS Trusted Advisor
- C. AWS CloudTrail
- D. Amazon CloudWatch

**2.** A compliance team needs a continuously updated list of which security groups currently allow unrestricted inbound SSH. Which service is designed for this?

- A. CloudTrail with an event filter
- B. CloudWatch Logs Insights
- C. Amazon Inspector
- D. AWS Config with a managed rule

**3.** A CloudTrail trail is created in ap-southeast-2 only. An engineer makes changes in us-east-1. What happens?

- A. The changes are not recorded by that trail unless it is multi-region
- B. The changes are recorded, because CloudTrail is always global
- C. CloudTrail automatically creates a trail in the new region
- D. The changes are recorded but only for 90 days

**4.** A company enables CloudTrail data events for all S3 buckets and receives an unexpectedly large bill. Why?

- A. Management events are charged per event
- B. Log file validation adds a per-event charge
- C. Multi-region trails cost double
- D. Data events log every object-level operation, which on busy buckets is millions of events

**5.** Which budget notification type warns you before the money is spent?

- A. FORECASTED at 100%
- B. ACTUAL at 100%
- C. Neither — budgets only report after the fact
- D. ACTUAL at 80%

**6.** A workload runs 24/7 with predictable, steady usage for the next three years. Which pricing model minimises cost?

- A. On-demand instances
- B. Spot instances
- C. A Compute Savings Plan or Reserved Instances
- D. Dedicated hosts

**7.** A batch job can be interrupted and restarted at any time, and runs whenever capacity is cheap. Which purchasing option fits?

- A. Reserved Instances
- B. Spot Instances
- C. Savings Plans
- D. On-demand with an Auto Scaling group

**8.** An organisation must prevent any member account from disabling CloudTrail, including by the account's root user. What achieves this?

- A. Enabling log file validation
- B. An IAM policy denying cloudtrail:StopLogging on each account's admin role
- C. A service control policy in AWS Organizations
- D. A permission boundary applied to all roles

**9.** Which statement correctly distinguishes CloudWatch from CloudTrail?

- A. They are the same service under different names
- B. CloudWatch records API calls; CloudTrail records metrics
- C. CloudWatch is for billing; CloudTrail is for performance
- D. CloudWatch records metrics and logs about behaviour; CloudTrail records who made which API calls

**10.** A company wants to allocate AWS costs to individual teams. What is the prerequisite?

- A. A consistent tagging strategy with cost allocation tags activated
- B. Separate AWS accounts for every team
- C. Enabling CloudTrail data events
- D. Purchasing Reserved Instances per team

**11.** Which statement about AWS Config pricing is correct?

- A. It charges a flat monthly fee per region
- B. It is included with a Business support plan
- C. It charges per configuration item recorded and per rule evaluation
- D. It is free for the first 100 rules

**12.** Which service provides recommendations across cost, performance, security, fault tolerance and service limits?

- A. AWS Compute Optimizer
- B. AWS Config
- C. AWS Trusted Advisor
- D. Amazon Inspector

---

## Answers

**1 — C.** **CloudTrail is a ledger of API calls** — who, when, from where, and what parameters. Config records resource *state* and would show the bucket vanished, but not who did it. CloudWatch records metrics and logs about behaviour. Any question with "who", "when" or "which user" is CloudTrail.

**2 — D.** **Config evaluates current resource state against rules** and reports compliant or non-compliant, with configuration history. The managed rule here is `INCOMING_SSH_DISABLED`. CloudTrail would show the API call that opened the port, but cannot list what is open right now.

**3 — A.** A single-region trail records only that region's events, so activity elsewhere is invisible to it. **Always create multi-region trails**, and enable global service events. Note that the console's 90-day Event History exists in every region regardless, which sometimes masks the gap until an audit.

**4 — D.** The first copy of **management events** is free. **Data events** — every GetObject, PutObject, Lambda invoke — are charged per event and are the standard cause of a shocking CloudTrail bill. Enable them selectively, on the buckets that actually need object-level auditing.

**5 — A.** A **FORECASTED** notification projects the month's trend and fires when the projection crosses the threshold — before the spend happens, which is the only alert that leaves time to act. ACTUAL alerts fire after the money is gone, and are the backstop for a spike the forecast has not caught.

**6 — C.** **Savings Plans and Reserved Instances** trade a one- or three-year commitment for up to ~72% off — the right answer whenever usage is described as steady and predictable. Spot suits interruptible work. Dedicated hosts address licensing and compliance isolation, not cost.

**7 — B.** **Spot** offers up to 90% off spare capacity, reclaimed with a two-minute warning — ideal for fault-tolerant, interruptible work such as batch processing, CI and rendering. The exam signals Spot with "interruptible", "fault-tolerant", "flexible start and end times".

**8 — C.** A **service control policy** is a ceiling on an entire account and **applies to the root user too**. IAM policies can be edited by an account administrator. A permission boundary only affects principals that carry it. Log file validation detects tampering but does not prevent stopping the trail.

**9 — D.** **CloudWatch** answers how busy, how slow, how many errors — metrics, logs and alarms about behaviour. **CloudTrail** answers who called what, and when. **Config** is the third: what a resource looks like now and whether that is allowed. Questions routinely offer one when they need another.

**10 — A.** **Cost allocation tags** — activated in the billing console and applied consistently — let Cost Explorer and billing reports break spend down by team, project or environment. Separate accounts also work and give harder boundaries, but tagging is the prerequisite either way, and an untagged resource is unattributable.

**11 — C.** Config bills roughly **$0.003 per configuration item recorded** plus about $0.001 per rule evaluation. Recording `AllSupported` resource types in a busy account generates items on every change and is a common source of unexpected charges — which is why this lab scopes the recorder to four types.

**12 — C.** **Trusted Advisor** spans five pillars, though the full check set requires a Business or Enterprise support plan. **Compute Optimizer** is narrower and deeper: right-sizing recommendations for EC2, EBS, Lambda and ECS based on observed utilisation. Inspector scans workloads for vulnerabilities.

---

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
