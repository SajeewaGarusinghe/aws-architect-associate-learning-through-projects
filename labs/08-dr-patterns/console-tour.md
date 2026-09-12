# Console tour — Lab 08

Keep [the architecture diagram](docs/architecture.html) open. Budget ~15 minutes.

---

## 0. Wait for the health check (2 min)

**Route 53 → Health checks → `saa-lab-08-primary-hc`.**

It starts `Unknown` and needs 60–90 seconds to report `Healthy`. Querying before then returns the
secondary — that is the check initialising, not a failure.

The **Health checkers** tab shows individual checker regions reporting independently. Failover
needs enough of them to agree, which is what prevents one bad network path triggering a false alarm.

## 1. Resolve it (2 min)

The zone is for a domain nobody owns, so it will never resolve through public DNS. Query its own
nameservers directly — take the first from the stack's `Nameservers` output:

```bash
NS=$(aws cloudformation describe-stacks --stack-name saa-lab-08-dr-patterns \
  --query "Stacks[0].Outputs[?OutputKey=='Nameservers'].OutputValue" --output text | awk '{print $1}')
dig +short @$NS www.saa-lab-08.example A
```

**`203.0.113.10`** — the PRIMARY. **Route 53 → Hosted zones → the zone** shows two records with the
same name, distinguished by `Failover: PRIMARY` and `SECONDARY` and their set identifiers.

Note the **TTL of 60**. That number is a floor on your recovery time: a resolver that answers now
keeps serving this value for up to a minute no matter how fast Route 53 reacts.

## 2. Failover (5 min) — the main event

Start watching, and leave it running:

```bash
while true; do printf '%s  %s\n' "$(date +%H:%M:%S)" "$(dig +short @$NS www.saa-lab-08.example A)"; sleep 5; done
```

In a second terminal, break the health check:

```bash
aws route53 update-health-check --health-check-id <HealthCheckId> \
  --resource-path /this-path-does-not-exist
```

| Elapsed | What you see |
|---|---|
| 0 s | `203.0.113.10` — primary |
| ~30 s | Health check shows its first failure |
| ~60 s | Two consecutive failures → `Unhealthy` |
| ~60–90 s | The loop starts printing **`198.51.100.20`** |

**Nothing was edited.** Both records existed the whole time; only which one was *eligible to
answer* changed.

Restore it and watch failback:

```bash
aws route53 update-health-check --health-check-id <HealthCheckId> --resource-path /
```

> **The number that matters:** the gap between breaking the check and the answer changing is your
> detection time. Add the TTL and you have the real recovery time — which is why a 3600-second TTL
> would have made this an hour-long outage regardless of how fast Route 53 noticed.

## 3. Recovery point (4 min) — the other half

Failover moved traffic. It did nothing for data. That half is decided in advance:

```bash
BUCKET=$(aws cloudformation describe-stacks --stack-name saa-lab-08-dr-patterns \
  --query "Stacks[0].Outputs[?OutputKey=='DataBucket'].OutputValue" --output text)

echo "version one"  > /tmp/f.txt && aws s3 cp /tmp/f.txt s3://$BUCKET/f.txt
echo "version two"  > /tmp/f.txt && aws s3 cp /tmp/f.txt s3://$BUCKET/f.txt
aws s3api list-object-versions --bucket $BUCKET --prefix f.txt \
  --query 'Versions[].{id:VersionId,latest:IsLatest,when:LastModified}' --output table
```

Both versions exist. Now delete it and look again:

```bash
aws s3 rm s3://$BUCKET/f.txt
aws s3api list-object-versions --bucket $BUCKET --prefix f.txt \
  --query '{versions:length(Versions),markers:length(DeleteMarkers)}' --output table
```

The object looks gone, but nothing was destroyed — a **delete marker** became the current version.
Remove the marker and the object returns. This is also why a versioned bucket is not empty for
teardown purposes.

**DynamoDB → Tables → `saa-lab-08-orders` → Backups** shows point-in-time recovery **enabled**,
with an earliest and latest restorable time. It restores to a **new** table, never in place.

> Neither versioning nor PITR is retroactive. Enabling them after the mistake recovers nothing —
> which is the entire point of the bottom half of the diagram.

---

## Then

```bash
./labs/08-dr-patterns/verify/checks.sh
./scripts/teardown.sh labs/08-dr-patterns --yes
```

Teardown is ~2 minutes. **Empty the bucket including versions and delete markers first**, or the
stack deletion will fail on a non-empty bucket.
