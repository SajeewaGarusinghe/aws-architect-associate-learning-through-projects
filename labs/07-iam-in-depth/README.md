# Lab 07 — How IAM actually decides

Every other lab used IAM as scenery. This one makes it the subject: two roles with identical
permission policies and opposite effective permissions, an explicit deny that nothing overrides,
and a resource policy granting access the identity policy never mentions.

**Architecture document:** [`docs/architecture.html`](docs/architecture.html) — open this first.

## What gets built

Seven resources, none of which run, store or serve anything:

- A **permission boundary** allowing only `s3:Get*` and `s3:List*`
- An **over-broad policy** allowing `s3:*` and `ec2:*`, attached to **both** roles
- A **bounded role** (policy + boundary) and an **unbounded role** (policy only) — the control case
- An **ABAC role** permitting EC2 start/stop only where the resource's `team` tag matches its own
- A **vault bucket** whose policy explicitly denies one role and explicitly allows another

## Exam domains

| Domain | Weight | Covered here |
|---|---|---|
| D1 — Design Secure Architectures | 30% | Evaluation order, boundaries, explicit deny, resource policies, ABAC, least privilege |

## The three ideas worth keeping

1. **Explicit deny wins, always** — over AdministratorAccess, over the account root, over everything.
2. **A boundary grants nothing.** Effective permissions are the *intersection* of identity policy
   and boundary; a boundary with no identity policy yields zero access.
3. **Within one account, identity OR resource policy is enough.** Cross-account needs both.

## Runbook

```bash
./scripts/deploy.sh  labs/07-iam-in-depth --yes    # under a minute
#   → console-tour.md  (~20 min, no rush — nothing is billing)
./labs/07-iam-in-depth/verify/checks.sh            # every claim via the policy simulator
./scripts/teardown.sh labs/07-iam-in-depth --yes
```

## Cost

**$0.00 — genuinely nothing.** IAM roles, policies, boundaries and the policy simulator are all
free. This is the one lab in the curriculum you could leave running indefinitely at no cost.
