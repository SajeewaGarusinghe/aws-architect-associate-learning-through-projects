# Progress

Account `213104855858` · region `ap-southeast-2` · one lab at a time, destroyed after each.

## Labs

| # | Lab | Status | Live for | Cost | Domains |
|---|---|---|---|---|---|
| 01 | [VPC from scratch](labs/01-vpc-from-scratch/) | **Deployed & destroyed** 2026-09-12 | 19 min | $0.0368 | D1 D2 D4 |
| 02 | [ALB + Auto Scaling](labs/02-alb-autoscaling/) | Ready to deploy | — | — | D1 D2 D3 D4 |
| 03 | [RDS Multi-AZ](labs/03-rds-multi-az/) | Ready to deploy | — | — | D1 D2 D4 |
| 04 | [Serverless API](labs/04-serverless-api/) | Ready to deploy | — | — | D1 D3 D4 |
| 05 | [Decoupling](labs/05-decoupling/) | Ready to deploy | — | — | D2 D3 D4 |
| 06 | [Static site + CDN](labs/06-static-site-cdn/) | Ready to deploy | — | — | D1 D3 D4 |
| 07 | [IAM in depth](labs/07-iam-in-depth/) | Ready to deploy | — | — | D1 |
| 08 | [DR patterns](labs/08-dr-patterns/) | Ready to deploy | — | — | D1 D2 |
| 09 | [Caching](labs/09-caching/) | Ready to deploy | — | — | D1 D3 D4 |
| 10 | [Cost & governance](labs/10-cost-governance/) | Ready to deploy — needs `params.json` | — | — | D1 D4 |

**Running total: $0.0368**

Every lab is authored, validated and change-set previewed. Phase A is complete for all ten.

## What each lab costs while live

| Lab | $/hour | Deploy | Teardown | Notes |
|---|---:|---|---|---|
| 01 VPC | 0.116 | ~3 min | ~2 min | NAT gateway is 51% of it |
| 02 ALB + ASG | 0.052 | 4–5 min | ~4 min | Cheaper than 01 — no NAT |
| 03 RDS Multi-AZ | 0.078 | **12–15 min** | ~8 min | Creation time is a real cost here |
| 04 Serverless | **0.000** | <2 min | <1 min | Nothing bills at rest |
| 05 Decoupling | **0.000** | <2 min | <1 min | Per-request only |
| 06 S3 + CloudFront | **0.000** | 3–5 min | ~4 min | Empty the versioned bucket |
| 07 IAM | **0.000** | <1 min | <1 min | Genuinely free |
| 08 DR patterns | 0.0014 | <2 min | ~2 min | Zone + health check, $1/month |
| 09 Caching | 0.028 | 6–9 min | **8–12 min** | ENIs must detach |
| 10 Governance | ~0.000 | 2–3 min | 3–4 min | Config bills per item |

**Suggested auto-teardown windows:** 1800s for most, **2400s for lab 03**, **2100s for lab 09**.

## Account baseline

What `./scripts/verify-clean.sh` expects when no lab is running:

- 1 running EC2 instance — `i-0c1da89383976a124` (`t3.small`), the current session host.
  **Protected.** A second instance `i-02060040f8335f406` (`c7i-flex.large`) is **stopped**,
  kept after an AMI migration; also protected, and never a teardown target.
- 2 VPCs — `vpc-0f4d9a74d92ad4dfc` (session, `10.0.0.0/16`) and `vpc-0ac6952c1ea149bbb`
  (default, `172.31.0.0/16`). **Both protected.**
- 0 NAT gateways, 0 load balancers, 0 RDS instances, 0 unassociated Elastic IPs,
  0 interface endpoints, 0 `saa-lab-*` stacks.

Anything else is a leak from a previous lab; investigate before starting a new one.

Verified clean: **2026-09-12 09:09Z** — after Lab 01 teardown. Re-verified after the host migration; `verify-clean.sh` now asks the metadata service which instance it is running on rather than trusting a hardcoded id.

## Account constraints worth remembering

- **The free plan rejects non-free-tier EC2 types** at `RunInstances`, and neither `--dry-run` nor
  a CloudFormation change-set preview reports it — the deploy fails partway and rolls back, having
  already billed for what it created first. `preflight.sh` checks this. Eligible x86 types:
  `t3.micro`, `t3.small`, `c7i-flex.large`, `m7i-flex.large` (plus `t4g.micro`, `t4g.small`).
  Labs 05–10 avoid EC2 entirely.
- **Cost Explorer is not enabled**, so every figure in this repo is estimated from published
  ap-southeast-2 rates rather than queried. Enabling it is free but takes 24 hours to populate.
- **In-place instance resize is blocked** by the same plan restriction — migrate via AMI instead.

## Suggested order

The labs build on each other, but only loosely. If you are picking rather than working through:

1. **Start with 01** — everything else assumes the networking it teaches.
2. **02 then 03** — stateless scaling, then the state problem that complicates it.
3. **04 and 05 together** — the serverless pair, both free, both fast.
4. **07 whenever** — free, no timer, and the IAM evaluation order pays off everywhere else.
5. **06, 08, 09, 10** in any order.
