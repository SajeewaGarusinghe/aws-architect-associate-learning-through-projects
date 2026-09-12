# Lab 02 — ALB + Auto Scaling across two AZs

A real workload inside the network shape Lab 01 built. The private subnet in AZ&nbsp;b, left
deliberately empty last time, now runs half the fleet.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

A `10.30.0.0/16` VPC across `ap-southeast-2a` and `2b`:

- An **internet-facing Application Load Balancer** with a node in each public subnet
- A **target group** on HTTP :80, health check `/` every 15s, deregistration delay cut to 30s
- An **Auto Scaling group** — min 2, desired 2, max 4 — spread across both private subnets,
  with health check type **`ELB`** rather than the default `EC2`
- Two `t3.micro` instances serving a page that names their own instance ID and availability zone
- An app security group whose inbound rule names **the ALB's security group** as its source,
  not a CIDR range
- **No NAT gateway and no default route** — the web tier has no internet path whatsoever

The instances build their page at boot from instance metadata using `python3` from the AMI, so
nothing is ever downloaded. That is what makes zero egress possible.

## Exam domains

| Domain | Weight | What this lab covers |
|---|---|---|
| D2 — Design Resilient Architectures | 26% | Multi-AZ load balancing, automatic instance replacement, health check types, blast radius of one AZ |
| D3 — Design High-Performing Architectures | 24% | Horizontal scaling, stateless tiers, connection termination at the ALB, launch templates |
| D1 — Design Secure Architectures | 30% | Security-group chaining, no public IPs, IMDSv2, single internet-facing ingress point |
| D4 — Design Cost-Optimized Architectures | 20% | Removing the NAT gateway entirely, right-sizing the fleet |

## The three ideas worth keeping

1. **The target group decides who gets traffic; the Auto Scaling group decides who exists.**
   They only agree because health check type is `ELB`. At the default `EC2`, a broken web server
   on a healthy host is removed from the load balancer and then never replaced.
2. **A security group can name another security group as its source.** The permission follows the
   load balancer rather than an address range, so it survives instance replacement and subnet
   changes — and admits nothing else.
3. **Egress is a design choice, not a default.** This tier needs none, so it gets none: no NAT
   gateway, no default route. That single decision saves more per hour than the load balancer costs.

## Runbook

```bash
./scripts/verify-clean.sh                             # confirm baseline first
./scripts/deploy.sh  labs/02-alb-autoscaling          # preview — free
./scripts/deploy.sh  labs/02-alb-autoscaling --yes    # build — meter starts
./scripts/console-links.sh labs/02-alb-autoscaling    # deep links for the tour
#   → work through console-tour.md  (~14 min)
./labs/02-alb-autoscaling/verify/checks.sh            # doc vs reality
./scripts/teardown.sh labs/02-alb-autoscaling --yes   # destroy + verify
```

**Deploy takes 4–5 minutes** and targets need up to a minute more to pass two health checks.
A 503 immediately after deploy is expected, not a fault.

**Teardown takes about 4 minutes** — the Auto Scaling group must terminate its instances before
the subnets can be deleted. Do not terminate them by hand to hurry it along; the group will just
replace them.

## Cost

$0.0516/hour while live — ALB $0.0252, two `t3.micro` $0.0264. A twenty-minute window is
**about 1.7 cents**, cheaper than Lab 01 because there is no NAT gateway.

## Files

| | |
|---|---|
| `docs/architecture.html` | The architecture document and topology diagram |
| `infra/template.yaml` | The CloudFormation stack |
| `console-tour.md` | Click-by-click guide, including two failure injections |
| `verify/checks.sh` | Read-only assertions: live account vs documented design |
| `exam-notes.md` | Exam-style questions, written after the console tour |
| `teardown-report.md` | Generated at teardown |
