# Lab 01 — VPC from scratch

The densest single topic on the SAA-C03 exam, and the foundation every later lab is built
inside. One CloudFormation stack, deployed for about twenty minutes, then destroyed.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.
It carries the topology diagram everything below refers to.

## What gets built

A `10.20.0.0/16` VPC across `ap-southeast-2a` and `2b`:

- Two public subnets (`10.20.1.0/24`, `10.20.2.0/24`) and two private (`10.20.11.0/24`, `10.20.12.0/24`)
- An internet gateway, and one NAT gateway with an Elastic IP in public subnet A
- Separate public and private route tables — the only thing that makes a subnet "public"
- A `t3.micro` in a private subnet with **no public IP, no key pair, and no inbound security-group rule**,
  reachable only through Session Manager
- Three SSM interface endpoints (`ssm`, `ssmmessages`, `ec2messages`) plus a free S3 gateway endpoint
- A custom network ACL alongside the security group, so the stateful/stateless difference is visible
- VPC flow logs to CloudWatch

## Exam domains

| Domain | Weight | What this lab covers |
|---|---|---|
| D1 — Design Secure Architectures | 30% | Subnet isolation, security groups vs NACLs, Session Manager instead of bastion hosts, IAM instance roles |
| D2 — Design Resilient Architectures | 26% | Multi-AZ subnet layout, single-NAT blast radius, independent management path |
| D4 — Design Cost-Optimized Architectures | 20% | NAT gateway pricing, gateway vs interface endpoints, cross-AZ data charges |

## The three ideas worth keeping

1. **A subnet is public only because of its route table.** Nothing on the subnet marks it.
2. **Security groups are stateful; network ACLs are stateless.** That is why the NACL needs an
   explicit inbound rule for ephemeral ports 1024–65535 and the security group does not.
3. **Give the management plane its own path.** Session Manager over interface endpoints keeps
   working when the internet route is gone — which is exactly when you need it.

## Runbook

```bash
./scripts/verify-clean.sh                                  # confirm baseline first
./scripts/deploy.sh  labs/01-vpc-from-scratch              # preview — free
./scripts/deploy.sh  labs/01-vpc-from-scratch --yes        # build — meter starts
./scripts/console-links.sh labs/01-vpc-from-scratch        # deep links for the tour
#   → work through console-tour.md  (~12 min)
./labs/01-vpc-from-scratch/verify/checks.sh                # doc vs reality
./scripts/teardown.sh labs/01-vpc-from-scratch --yes       # destroy + verify
```

## Cost

$0.116/hour while live — NAT gateway $0.059, three interface endpoints $0.039, `t3.micro`
$0.0132, Elastic IP $0.005. A twenty-minute window is **about four cents**.

The NAT gateway alone would be roughly **$43/month** if left running. That is why teardown
verifies by tag sweep instead of trusting `DELETE_COMPLETE`.

## Files

| | |
|---|---|
| `docs/architecture.html` | The architecture document and topology diagram |
| `infra/template.yaml` | The CloudFormation stack |
| `console-tour.md` | Click-by-click observation guide, keyed to the diagram |
| `verify/checks.sh` | Read-only assertions: live account vs documented design |
| `exam-notes.md` | Exam-style questions, written after the console tour |
| `teardown-report.md` | Generated at teardown: what was deleted, how long it ran, what it cost |
