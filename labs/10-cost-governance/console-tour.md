# Console tour — Lab 10

Keep [the architecture diagram](docs/architecture.html) open. Budget ~20 minutes.

**Before deploying**, create the parameter file with your email — the template has no default, and
the file is gitignored because this repository is public:

```bash
cp labs/10-cost-governance/infra/params.example.json labs/10-cost-governance/infra/params.json
# edit it, then deploy
```

---

## 1. Confirm the budget subscription (2 min)

Check your inbox for an AWS Notifications confirmation and click it. **An unconfirmed subscription
sends nothing** — the budget exists, looks configured, and silently never alerts. This is the most
common reason a budget alert fails to fire.

**Billing → Budgets → `saa-lab-10-monthly`** shows the $5 limit and two notifications:

| Type | Threshold | Fires |
|---|---|---|
| `ACTUAL` | 50% | after $2.50 is spent |
| `FORECASTED` | 100% | when the month's *projection* crosses $5 |

Only the forecast alert gives you time to act. The actual alert is the backstop for a sudden spike
the forecast has not caught up with.

## 2. Read your own history (5 min) — the payoff of this lab

Nine labs have been created and destroyed in this account. CloudTrail recorded all of it:

```bash
aws cloudtrail lookup-events --max-results 20 \
  --query 'Events[].{time:EventTime,user:Username,event:EventName}' --output table

# Every stack this curriculum created and destroyed
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateStack \
  --query 'Events[].{time:EventTime,user:Username}' --output table

# And every NAT gateway
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateNatGateway \
  --query 'Events[].{time:EventTime,user:Username}' --output table
```

That is the ledger: **who, when, from where**. Note that `lookup-events` reads the last 90 days
without touching the S3 bucket at all — the bucket is for retention and analysis, not for answering
"who deleted that".

**CloudTrail → Trails → `saa-lab-10-trail`** shows multi-region `Yes` and log file validation
`Enabled`. A single-region trail would have missed anything done elsewhere; validation writes digest
files so tampering is detectable, which is the difference between a log and evidence.

## 3. Config: the other question (4 min)

**Config → Resource inventory.** The recorder is scoped to four resource types, not everything —
Config bills **per configuration item recorded**, and `AllSupported` in a busy account is a
genuinely common surprise charge.

**Config → Rules** shows two managed rules with their compliance state. Evaluation takes a few
minutes after deploy; Config is for governance, not real-time prevention.

## 4. Failure injection (5 min) — break a rule and find the culprit

Create something deliberately non-compliant:

```bash
VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SG=$(aws ec2 create-security-group --group-name lab10-bad-ssh \
  --description "deliberately non-compliant" --vpc-id $VPC --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG \
  --protocol tcp --port 22 --cidr 0.0.0.0/0
```

Within a few minutes, **Config → Rules → `saa-lab-10-no-unrestricted-ssh`** marks it
`NON_COMPLIANT` and names the resource.

Now ask the other question:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --query 'Events[0].{time:EventTime,user:Username}' --output table
```

**Config found it. CloudTrail explained it.** Two services, two halves of one answer — and the exam
routinely offers one when the question needs the other.

Clean up:

```bash
aws ec2 delete-security-group --group-id $SG
```

---

## Then

```bash
./labs/10-cost-governance/verify/checks.sh
./scripts/teardown.sh labs/10-cost-governance --yes
```

Teardown is 3–4 minutes; the recorder stops before the delivery channel can go, and the bucket is
emptied by the lifecycle rule.

> **Consider keeping the budget.** It is free, account-wide, and it is the backstop this whole
> curriculum has been missing — it catches anything a future teardown ever misses. Recreate it on
> its own with `aws budgets create-budget` if you want it to outlive this stack.
