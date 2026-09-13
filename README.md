# AWS Architect Associate — Learning Through Projects

Studying for the AWS Certified Solutions Architect – Associate (SAA-C03) exam by **building** the
architectures rather than reading about them. Eleven labs, each deployed into a real AWS account,
inspected in the console against its own architecture diagram, deliberately broken to see what
happens, then destroyed.

**[Progress and cost tracker →](PROGRESS.md)**

---

## The eleven labs

Each has an architecture document with a hand-drawn topology diagram, a CloudFormation template, a
click-by-click console tour with a failure injection, a read-only verification script, and twelve
exam-style questions.

| # | Lab | Builds | Idle $/hr | Domains |
|---|---|---|---:|---|
| 01 | [VPC from scratch](labs/01-vpc-from-scratch/) | Two-AZ VPC, NAT gateway, SSM endpoints, SG vs NACL | 0.116 | D1 D2 D4 |
| 02 | [ALB + Auto Scaling](labs/02-alb-autoscaling/) | Internet-facing ALB, ASG across two AZs, no egress | 0.052 | D1 D2 D3 D4 |
| 03 | [RDS Multi-AZ](labs/03-rds-multi-az/) | Synchronous standby, managed password, measured failover | 0.078 | D1 D2 D4 |
| 04 | [Serverless API](labs/04-serverless-api/) | API Gateway + Lambda + DynamoDB, no VPC at all | **0.000** | D1 D3 D4 |
| 05 | [Decoupling](labs/05-decoupling/) | SNS fan-out, SQS, filter policy, dead-letter queue | **0.000** | D2 D3 D4 |
| 06 | [Static site + CDN](labs/06-static-site-cdn/) | Private bucket served publicly via CloudFront OAC | **0.000** | D1 D3 D4 |
| 07 | [IAM in depth](labs/07-iam-in-depth/) | Permission boundaries, explicit deny, ABAC, simulator | **0.000** | D1 |
| 08 | [DR patterns](labs/08-dr-patterns/) | Route 53 failover, health checks, versioning, PITR | 0.0014 | D1 D2 |
| 09 | [Caching](labs/09-caching/) | Cache-aside with Redis, VPC Lambda, gateway endpoint | 0.028 | D1 D3 D4 |
| 10 | [Cost & governance](labs/10-cost-governance/) | CloudTrail, Config rules, budgets with forecast alerts | ~0.000 | D1 D4 |
| 11 | [DynamoDB deep dive](labs/11-dynamodb-deep-dive/) | GSI + LSI, conditional writes, transactions, Streams → Lambda, TTL, PITR | **0.000** | D1 D3 D4 |

**Total cost to run all eleven** — deploying each, touring it, and destroying it — is well under $1.

### Exam domain coverage

| Domain | Weight | Labs |
|---|---|---|
| D1 — Design Secure Architectures | 30% | 01, 02, 03, 06, 07, 08, 09, 10, 11 |
| D2 — Design Resilient Architectures | 26% | 01, 02, 03, 05, 08 |
| D3 — Design High-Performing Architectures | 24% | 02, 04, 05, 06, 09, 11 |
| D4 — Design Cost-Optimized Architectures | 20% | 01, 02, 03, 04, 05, 06, 09, 10, 11 |

---

## How a lab works

Three phases, and **only the middle one costs money**:

| Phase | Time | Cost | |
|---|---|---|---|
| **A — Prepare** | 60–90 min | $0.00 | Architecture document and diagram, author and validate the template, pre-write the console checklist |
| **B — Live** | 15–20 min | < $0.10 | Deploy → tour the console against the diagram → break something → tear down |
| **C — Consolidate** | 30–45 min | $0.00 | Exam questions on what was observed, cost report, commit |

Everything is authored and validated before deploy, so the metered window is never spent on syntax
errors.

```bash
./scripts/verify-clean.sh                      # confirm the account is at baseline
./scripts/preflight.sh  labs/01-vpc-from-scratch
./scripts/deploy.sh     labs/01-vpc-from-scratch          # preview — free
./scripts/deploy.sh     labs/01-vpc-from-scratch --yes    # build — meter starts
./scripts/auto-teardown.sh labs/01-vpc-from-scratch 1800  # 30-minute backstop
./scripts/console-links.sh labs/01-vpc-from-scratch       # deep links for the tour
./labs/01-vpc-from-scratch/verify/checks.sh               # live account vs the document
./scripts/teardown.sh   labs/01-vpc-from-scratch --yes    # destroy + verify by tag sweep
```

---

## Safety rails

The machine running these labs is an EC2 instance **inside the same AWS account**. Destroying it
would destroy the working environment, so the scripts enforce:

- **A protected list** in [`scripts/guardrails.sh`](scripts/guardrails.sh) — the session host and
  both pre-existing VPCs. Teardown refuses to act on any of them.
- **One stack per lab**, named `saa-lab-NN-slug`. Teardown rejects any name that does not match, so
  an unrelated stack cannot be deleted by accident.
- **Tag-based orphan detection** — every lab resource carries `Project=saa-labs`; untagged
  resources are never touched.
- **Distinct CIDRs per lab** (`10.20`, `10.30`, `10.40`, `10.50`) — never `10.0.0.0/16`, which the
  session VPC uses. Overlapping CIDRs can never be peered.
- **Verified teardown** — after `DELETE_COMPLETE`, the script re-queries EC2, S3 and RDS by tag and
  fails loudly if anything answers.
- **An auto-teardown timer** that runs detached, so a stack still comes down if the terminal, the
  agent, or the session goes away.
- **A preflight check** — this account is on the AWS free plan, which rejects non-free-tier
  instance types at `RunInstances`, and **neither `--dry-run` nor a change-set preview catches it**.
  `preflight.sh` checks eligibility and quota headroom before the meter starts.

---

## Scripts

| | |
|---|---|
| `verify-clean.sh` | Account-wide sweep — run first, every session |
| `preflight.sh LAB` | Free-tier eligibility, quota headroom, template validity |
| `deploy.sh LAB` | Validate and preview a change set; `--yes` to build |
| `auto-teardown.sh LAB SECS` | Detached timer; `--cancel` and `--status` |
| `console-links.sh LAB` | Console deep links for the tour |
| `teardown.sh LAB --yes` | Delete, wait, verify by tag, write the cost report |
| `cost-report.sh LAB` | Live minutes × published rates |
| `make-doc.py LAB` | Wraps a lab's `docs/body.html` in the shared house style |
| `make-quiz.py LAB --notes` | Builds the drill **and** `exam-notes.md` from one `quiz.json` |

Labs needing a value that must not be public (lab 10's budget email) read
`labs/NN-.../infra/params.json`, which is gitignored. Copy the `params.example.json` beside it.

---

## Repository layout

```
scripts/                 shared tooling, guardrails and generators
  doc-shell.html         one palette and one set of SVG diagram classes for every document
labs/NN-name/
  README.md              what it builds, the exam domains, the runbook, the cost
  infra/template.yaml    the CloudFormation stack
  docs/body.html         document content; make-doc.py wraps it in the house style
  docs/architecture.html the generated, printable architecture document
  docs/exam-quiz.html    the generated interactive drill
  quiz.json              twelve questions — the single source for both the drill and the notes
  notes-extra.md         traps and reference tables appended to the notes
  exam-notes.md          generated: questions, answers, traps, reference tables
  console-tour.md        click-by-click guide, including the failure injection
  verify/checks.sh       read-only assertions: live account vs documented design
  teardown-report.md     generated at teardown: what ran, for how long, what it cost
```

The architecture documents are self-contained printable HTML — open one in a browser and
Print → Save as PDF produces a paginated document.

---

## Reference: the `aws-doc-create` skill

[`.claude/skills/aws-doc-create/`](.claude/skills/aws-doc-create/) is the Claude Code skill that
defines the house style every architecture document in this repo follows — the navy-and-amber
palette, the section anatomy, and the SVG diagram conventions. It is kept here so the documents stay
consistent from lab to lab and can be regenerated.
