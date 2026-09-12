# Console tour — Lab 04

Keep [the architecture diagram](docs/architecture.html) open beside the console. Budget about
12 minutes. This is the cheapest and fastest lab — deploy is under two minutes, and idle cost is
genuinely zero.

Most of this tour happens in a terminal rather than the console, because there is no
infrastructure to look at.

---

## 1. Call it (2 min)

Take `ApiUrl` from the stack outputs. Then, **twice in quick succession**:

```bash
curl -s https://<api-id>.execute-api.ap-southeast-2.amazonaws.com | jq
```

Compare `cold_start_age_seconds` between the two calls:

- **First call:** a small number. Lambda had to create an execution environment — download the
  code, start the Python runtime, and run everything outside the handler including the boto3
  client. That is the cold start.
- **Second call:** a larger number, and the response is noticeably faster. The environment was
  reused; only the handler body ran.

`request_id` differs every time. `cold_start_age_seconds` only resets when a *new* environment is
created — which is the distinction people usually get wrong about cold starts.

## 2. Write and read (2 min)

```bash
API=https://<api-id>.execute-api.ap-southeast-2.amazonaws.com
curl -s -XPOST $API/notes -d '{"text":"multi-az is for availability"}' | jq
curl -s -XPOST $API/notes -d '{"text":"read replicas are for scale"}' | jq
curl -s $API/notes | jq
```

The GET returns items newest-first. That ordering is not a sort in the function — it comes from
`ScanIndexForward: false` on a **Query** against the sort key, done inside DynamoDB.

**DynamoDB → Tables → `saa-lab-04-notes` → Explore table items.** Each item has `pk` = `note` and a
timestamp-prefixed `sk`. Every item shares one partition key, so one Query retrieves them in order
without reading anything else.

> On a real table you would not put everything in one partition — it concentrates traffic on a
> single one. Here it keeps the key design legible.

## 3. Notice what is absent (2 min)

Walk the console and confirm these are genuinely empty for this stack:

| Where | What you will find |
|---|---|
| VPC → Your VPCs | No new VPC. The stack created none. |
| EC2 → Instances | Nothing. |
| EC2 → Security groups | None created. |
| VPC → NAT gateways | None. |

The API reaches the function through a **resource policy**, and the function reaches the table
through an **execution role**. Both are IAM statements. There is no network path to configure,
which is why there is nothing here to misconfigure.

**Lambda → Functions → `saa-lab-04-api` → Configuration → Permissions** shows both sides: the
execution role at the top, the resource-based policy further down naming
`apigateway.amazonaws.com`.

## 4. Failure injection (4 min) — break one IAM action

This is the most useful debugging skill in the whole curriculum.

**IAM → Roles → `saa-lab-04-fn-role` → the `notes-table-access` policy → Edit → remove
`dynamodb:Query` from the action list → Save.**

IAM changes take effect within seconds. Now:

```bash
curl -s $API/notes | jq          # GET  → 500, error: ClientError
curl -s -XPOST $API/notes -d '{"text":"still works"}' | jq   # POST → 201
```

**Only the read broke.** PutItem was never denied, so writes continue normally — a precise
demonstration that IAM is evaluated per action, not per service.

Now read the actual error. **CloudWatch → Log groups → `/aws/lambda/saa-lab-04-api`** → newest
stream:

```
ERROR ClientError: An error occurred (AccessDeniedException) when calling the Query operation:
User: arn:aws:sts::…:assumed-role/saa-lab-04-fn-role/… is not authorized to perform:
dynamodb:Query on resource: arn:aws:dynamodb:…:table/saa-lab-04-notes
```

That message names **who** (the assumed role), **what** (`dynamodb:Query`) and **which resource**.
Learning to read these three fields fluently turns most IAM debugging into a ten-second job.

**Restore it:** add `dynamodb:Query` back to the policy. The next GET succeeds.

## 5. Throttling (2 min, optional)

**Lambda → `saa-lab-04-api` → Configuration → Concurrency → Reserve concurrency → `0` → Save.**

Every call now fails immediately — the function is capped at zero concurrent executions, so
nothing can run. Reserved concurrency is the guardrail against a runaway loop scaling up and
billing for it, and setting it to zero is the standard way to disable a function without deleting it.

Set it back to **Use unreserved account concurrency** afterwards.

---

## Then

```bash
./labs/04-serverless-api/verify/checks.sh
./scripts/teardown.sh labs/04-serverless-api --yes
```

Teardown is under a minute.

> **This is the one lab you could leave running** — it would cost nothing at all. It gets destroyed
> anyway, because the account returns to a known baseline after every lab and because
> `verify-clean.sh` should mean what it says.
