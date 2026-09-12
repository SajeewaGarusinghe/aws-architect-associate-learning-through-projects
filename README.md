# AWS Architect Associate — Learning Through Projects

Studying for the AWS Certified Solutions Architect – Associate (SAA-C03) exam by building the
architectures rather than reading about them. Each lab is deployed into a real AWS account,
inspected in the console against its own architecture diagram, deliberately broken to see what
happens, and then destroyed.

**[Progress and lab index →](PROGRESS.md)**

## How a lab works

Each lab is one CloudFormation stack and one folder. It runs in three phases, and **only the
middle one costs money**:

| Phase | Time | Cost | |
|---|---|---|---|
| **A — Prepare** | 60–90 min | $0.00 | Write the architecture document and diagram, author and validate the template, walk through it, pre-write the console checklist |
| **B — Live** | 15–20 min | < $0.10 | Deploy → tour the console against the diagram → break something → tear down |
| **C — Consolidate** | 30–45 min | $0.00 | Exam-style questions on what was observed, cost report, commit |

Everything is authored and validated before deploy, so the metered window is never spent on
syntax errors. Total estimated cost for the full ten-lab curriculum: **under $1.00**.

## Safety rails

The session host that runs these labs is an EC2 instance **inside the same AWS account**.
Destroying it would destroy the working environment, so the scripts enforce:

- A `PROTECTED` list in [`scripts/guardrails.sh`](scripts/guardrails.sh) — the session instance
  and both pre-existing VPCs. Teardown refuses to act on any of them.
- One stack per lab, named `saa-lab-NN-slug`. Teardown rejects any name that does not match,
  so an unrelated stack cannot be deleted by accident.
- Every lab resource tagged `Project=saa-labs`. Orphan detection is a tag query; untagged
  resources are never touched.
- Lab VPCs use `10.20.0.0/16` and up, never `10.0.0.0/16` — no overlap with the session VPC.
- Teardown is **verified, not assumed**: after `DELETE_COMPLETE` it re-queries EC2, S3 and RDS
  by tag and fails loudly if anything answers.
- `verify-clean.sh` runs at the start of every session to catch anything left behind.

## Scripts

| | |
|---|---|
| `scripts/verify-clean.sh` | Account sweep — run first, every session |
| `scripts/deploy.sh LAB` | Validate, preview a change set; `--yes` to build |
| `scripts/console-links.sh LAB` | Console deep links for the tour |
| `scripts/teardown.sh LAB` | Delete, wait, verify by tag, write the cost report |
| `scripts/cost-report.sh LAB` | Live minutes × published rates |

```bash
./scripts/verify-clean.sh
./scripts/deploy.sh labs/01-vpc-from-scratch          # preview, free
./scripts/deploy.sh labs/01-vpc-from-scratch --yes    # build
./scripts/teardown.sh labs/01-vpc-from-scratch --yes  # destroy
```

## Reference: the `aws-doc-create` skill

[`.claude/skills/aws-doc-create/`](.claude/skills/aws-doc-create/) is the Claude Code skill that
generates each lab's architecture document — a self-contained printable HTML page built around a
hand-drawn SVG topology diagram. It is kept in the repo so the documents stay consistent from
lab to lab, and so future readers can regenerate them.

- `SKILL.md` — the recipe: palette, document anatomy, diagram conventions
- `shell.html` — a ready-to-copy starting page
