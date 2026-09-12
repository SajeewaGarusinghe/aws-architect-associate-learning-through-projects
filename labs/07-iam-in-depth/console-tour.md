# Console tour — Lab 07

Keep [the architecture diagram](docs/architecture.html) open. Budget ~20 minutes.

**This lab costs nothing.** There is no meter, no timer, and no reason to hurry.

Most of it runs in a terminal, because the policy simulator answers precisely and the console's
rendering of effective permissions does not.

---

## 1. The boundary, demonstrated (5 min)

Both roles carry the **identical** `saa-lab-07-overbroad` policy: `s3:*` and `ec2:*` on `*`.

```bash
ACCT=$(aws sts get-caller-identity --query Account --output text)

# No boundary — the policy applies in full
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::$ACCT:role/saa-lab-07-unbounded \
  --action-names ec2:StartInstances s3:PutObject s3:GetObject \
  --query 'EvaluationResults[].{action:EvalActionName,decision:EvalDecision}' --output table

# Boundary attached — same policy, clamped
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::$ACCT:role/saa-lab-07-bounded \
  --action-names ec2:StartInstances s3:PutObject s3:GetObject \
  --query 'EvaluationResults[].{action:EvalActionName,decision:EvalDecision}' --output table
```

| Action | unbounded | bounded |
|---|---|---|
| `ec2:StartInstances` | `allowed` | `implicitDeny` |
| `s3:PutObject` | `allowed` | `implicitDeny` |
| `s3:GetObject` | `allowed` | `allowed` |

Effective permissions are the **intersection** of the identity policy and the boundary. Note that
the bounded role also loses `s3:PutObject` — the boundary allows `s3:Get*` and `s3:List*`, and a
write was never inside it.

**IAM → Roles → `saa-lab-07-bounded` → Permissions boundary tab** shows the policy doing this.

## 2. Explicit deny (5 min) — the rule nothing overrides

```bash
VAULT=$(aws s3api list-buckets --query "Buckets[?starts_with(Name,'saa-lab-07-vault')].Name|[0]" --output text)

aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::$ACCT:role/saa-lab-07-unbounded \
  --action-names s3:GetObject --resource-arns arn:aws:s3:::$VAULT/test.txt \
  --query 'EvaluationResults[].{action:EvalActionName,decision:EvalDecision}' --output table
```

`explicitDeny` — even though this role's identity policy allows `s3:*`.

**Now prove it properly.** In **IAM → Roles → `saa-lab-07-unbounded` → Add permissions → Attach
policies**, attach **AdministratorAccess**, then re-run the command above.

**It is still `explicitDeny`.** An explicit Deny in any applicable policy is evaluated first and
nothing overrides it — not an administrator policy, not the account root. Detach
AdministratorAccess afterwards.

## 3. A resource policy granting on its own (3 min)

The ABAC role's identity policy contains **no S3 statement at all** — only EC2 start/stop with a
tag condition. Yet:

```bash
aws s3api get-bucket-policy --bucket $VAULT --query Policy --output text | jq .
```

The second statement allows `saa-lab-07-abac` to `GetObject`. Within a single account, an allow in
**either** the identity policy or the resource policy is sufficient — which is why S3 access can
appear from nowhere when you are reading only the identity side.

> **Cross-account is different:** there, both the resource policy in the target account *and* the
> identity policy in the caller's account must allow it.

## 4. ABAC (3 min)

**IAM → Roles → `saa-lab-07-abac` → Tags** shows `team = research`. Its policy permits
`ec2:StartInstances` only where `aws:ResourceTag/team` equals `aws:PrincipalTag/team`.

One policy, any number of teams — including teams that do not exist yet. The trade-off is that
**tagging discipline becomes a security control**: an untagged instance matches nobody, and a
mistagged one matches the wrong team.

## 5. Read the boundary as a delegation tool (2 min)

The real-world use is a condition on `iam:CreateRole` requiring `iam:PermissionsBoundary`. That
lets a platform team create roles freely while guaranteeing none of them can exceed the ceiling —
delegation without privilege escalation. It is the canonical exam scenario for boundaries.

---

## Then

```bash
./labs/07-iam-in-depth/verify/checks.sh
./scripts/teardown.sh labs/07-iam-in-depth --yes
```

Teardown is under a minute. Empty the vault bucket first if you uploaded a test object.
