# Progress

Account `213104855858` · region `ap-southeast-2` · one lab at a time, destroyed after each.

## Labs

| # | Lab | Status | Live for | Cost | Domains |
|---|---|---|---|---|---|
| 01 | [VPC from scratch](labs/01-vpc-from-scratch/) | Deployed &amp; destroyed 2026-09-12 | 19 min | $0.0368 | D1 D2 D4 |
| 02 | [ALB + Auto Scaling, multi-AZ](labs/02-alb-autoscaling/) | Phase A complete — ready to deploy | — | — | D1 D2 D3 D4 |
| 03 | RDS Multi-AZ + failover test | Not started | | | D1 D2 |
| 04 | Serverless API (API Gateway + Lambda + DynamoDB) | Not started | | | D3 D4 |
| 05 | Decoupling (SQS, SNS fan-out, DLQ) | Not started | | | D2 D3 |
| 06 | Static site + CDN (S3, CloudFront, OAC) | Not started | | | D1 D4 |
| 07 | IAM in depth | Not started | | | D1 |
| 08 | DR patterns (pilot light, Route 53 failover) | Not started | | | D2 |
| 09 | Caching & performance (ElastiCache, read replicas) | Not started | | | D3 |
| 10 | Cost & governance (Config, CloudTrail, Budgets) | Not started | | | D4 D1 |

**Running total: $0.0368**

## Exam domain coverage

| Domain | Weight | Labs |
|---|---|---|
| D1 — Design Secure Architectures | 30% | 01, 03, 06, 07, 10 |
| D2 — Design Resilient Architectures | 26% | 01, 02, 03, 05, 08 |
| D3 — Design High-Performing Architectures | 24% | 02, 04, 05, 09 |
| D4 — Design Cost-Optimized Architectures | 20% | 01, 04, 06, 10 |

## Account baseline

What `./scripts/verify-clean.sh` expects to find when no lab is running:

- 1 running EC2 instance — `i-02060040f8335f406`, the session host. **Protected.**
- 2 VPCs — `vpc-0f4d9a74d92ad4dfc` (session, `10.0.0.0/16`) and `vpc-0ac6952c1ea149bbb`
  (default, `172.31.0.0/16`). **Both protected.**
- 0 NAT gateways, 0 load balancers, 0 RDS instances, 0 unassociated Elastic IPs,
  0 interface endpoints, 0 `saa-lab-*` stacks.

Anything else is a leak from a previous lab and should be investigated before starting a new one.

Verified clean: **2026-09-12 09:09Z** — after Lab 01 teardown
