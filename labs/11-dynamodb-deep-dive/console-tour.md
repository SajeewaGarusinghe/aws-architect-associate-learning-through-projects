# Console tour — Lab 11

Keep [the architecture diagram](docs/architecture.html) open beside the console. Budget about
20 minutes. Most of this happens in a terminal, because the interesting behaviour is in how
DynamoDB responds to specific API calls, not in anything visual.

Export the table name once:

```bash
TABLE=saa-lab-11-orders
```

---

## 1. The table shape (3 min)

**DynamoDB → Tables → `saa-lab-11-orders` → Indexes.** You should see:

- The base table, keyed on `pk` (partition) + `sk` (sort)
- `gsi1-status-by-time` — a **global secondary index**, its own partition key (`status`) and sort
  key (`createdAt`)
- `lsi1-by-total` — a **local secondary index**, same partition key as the base table (`pk`), but
  sorted by `total` instead of `sk`

**→ Additional settings** shows TTL (`expiresAt`, enabled) and point-in-time recovery (enabled).
Both were declared in the template, not clicked on afterward — that matters for the exam because
an LSI in particular **cannot** be added after table creation.

## 2. Seed a product and an order (2 min)

```bash
aws dynamodb put-item --table-name $TABLE --item '{
  "pk": {"S": "PRODUCT#widget"}, "sk": {"S": "PRODUCT#widget"},
  "stock": {"N": "3"}, "version": {"N": "1"}
}'
```

**Explore table items** in the console. Notice the item has no `status` or `total` attribute —
which is why it will never show up in either index. A GSI or LSI only ever contains items that
have every attribute in its key schema. That's a **sparse index**, and it's why you can put
completely different item shapes in one table without them tripping over each other's indexes.

## 3. Conditional writes (4 min) — the exam's favourite DynamoDB verb

```bash
# Succeeds: stock is 3, condition (stock > 0) holds
aws dynamodb update-item --table-name $TABLE \
  --key '{"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}}' \
  --update-expression 'SET stock = stock - :one, version = version + :one' \
  --condition-expression 'stock > :zero' \
  --expression-attribute-values '{":one":{"N":"1"},":zero":{"N":"0"}}'
```

Now force it to zero and try again:

```bash
aws dynamodb update-item --table-name $TABLE \
  --key '{"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}}' \
  --update-expression 'SET stock = :zero' \
  --expression-attribute-values '{":zero":{"N":"0"}}'

aws dynamodb update-item --table-name $TABLE \
  --key '{"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}}' \
  --update-expression 'SET stock = stock - :one' \
  --condition-expression 'stock > :zero' \
  --expression-attribute-values '{":one":{"N":"1"},":zero":{"N":"0"}}'
```

The second call fails with `ConditionalCheckFailedException` — **the update never happened**.
This is how DynamoDB enforces "don't oversell" or "don't overwrite a newer version" without a
lock, a transaction manager, or a second round trip to check first: the check and the write are
one atomic API call. The `version` attribute bumped in the first call is what a real system would
also condition on (`version = :expectedVersion`) to implement optimistic locking against
concurrent writers.

## 4. A transaction — two items change together or not at all (3 min)

```bash
aws dynamodb update-item --table-name $TABLE \
  --key '{"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}}' \
  --update-expression 'SET stock = :two' --expression-attribute-values '{":two":{"N":"2"}}'

aws dynamodb transact-write-items --transact-items '[
  {"Update": {"TableName":"'"$TABLE"'",
    "Key": {"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}},
    "UpdateExpression": "SET stock = stock - :one",
    "ConditionExpression": "stock > :zero",
    "ExpressionAttributeValues": {":one":{"N":"1"},":zero":{"N":"0"}}}},
  {"Put": {"TableName":"'"$TABLE"'",
    "Item": {"pk":{"S":"CUSTOMER#demo"},"sk":{"S":"ORDER#1"},
      "status":{"S":"PENDING"},"createdAt":{"S":"2026-01-01T00:00:00Z"},"total":{"N":"42"}}}}
]'
```

Both writes land, or — if the stock condition had failed — **neither would have**. That's the
whole value of `TransactWriteItems` over two separate calls: there is no window where the order
exists but the stock was never decremented. It costs roughly double the write capacity of doing
the same writes individually, which is the tradeoff the exam expects you to know.

## 5. Query the GSI and the LSI (3 min)

```bash
# Every PENDING order, across every customer — a Query, not a Scan.
# `status` is a DynamoDB reserved keyword, so it needs an expression alias.
aws dynamodb query --table-name $TABLE --index-name gsi1-status-by-time \
  --key-condition-expression '#s = :s' --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":s":{"S":"PENDING"}}'

# This one customer's orders, biggest first
aws dynamodb query --table-name $TABLE --index-name lsi1-by-total \
  --key-condition-expression 'pk = :p' \
  --expression-attribute-values '{":p":{"S":"CUSTOMER#demo"}}' --scan-index-forward false
```

Without `gsi1-status-by-time`, "every PENDING order" would require a Scan of the entire table —
reading every item, discarding the ones that don't match, and billing for all of it. Without
`lsi1-by-total`, sorting by total would mean fetching everything for that customer and sorting
client-side. Both indexes exist purely to turn an expensive access pattern into a cheap one.

## 6. Streams → Lambda (4 min) — watch a write turn into a side effect

```bash
aws dynamodb update-item --table-name $TABLE \
  --key '{"pk":{"S":"CUSTOMER#demo"},"sk":{"S":"ORDER#1"}}' \
  --update-expression 'SET #s = :shipped' --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":shipped":{"S":"SHIPPED"}}'
```

**CloudWatch → Log groups → `/aws/lambda/saa-lab-11-stream-processor`** → newest stream, within a
few seconds:

```
AUDIT CUSTOMER#demo#ORDER#1: status changed: PENDING -> SHIPPED
```

Then confirm it landed in the table too:

```bash
aws dynamodb query --table-name $TABLE \
  --key-condition-expression 'pk = :a' --expression-attribute-values '{":a":{"S":"AUDIT"}}'
```

Nothing polled the table. The update itself was the only trigger — DynamoDB Streams pushed the
before/after image of the item to the Lambda's event source mapping, which invoked the function
automatically. This is the mechanism behind cross-region global tables, search-index sync, and
"notify someone when a record changes" — all without the writer knowing any of it is happening.

## 7. Failure injection (3 min) — break the write-back permission

**IAM → Roles → `saa-lab-11-stream-role` → `stream-read-and-audit-write` → Edit → remove
`dynamodb:PutItem` → Save.**

```bash
aws dynamodb update-item --table-name $TABLE \
  --key '{"pk":{"S":"CUSTOMER#demo"},"sk":{"S":"ORDER#1"}}' \
  --update-expression 'SET #s = :cancelled' --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":cancelled":{"S":"CANCELLED"}}'
```

The `update-item` call above still succeeds — nothing about writing to the table changed. But the
log group now shows:

```
AccessDeniedException: ... is not authorized to perform: dynamodb:PutItem on resource: ...
```

**This is the difference between the two IAM statements in the role**: removing stream-read
permissions would stop the function from being invoked at all (no logs, no error — just silence).
Removing the write-back permission lets it run and fail loudly. Same root cause, very different
symptom, and telling them apart under exam pressure is the actual skill.

**Restore `dynamodb:PutItem`** before moving on.

## 8. TTL (2 min, background process — not instant)

```bash
aws dynamodb update-item --table-name $TABLE \
  --key '{"pk":{"S":"CUSTOMER#demo"},"sk":{"S":"ORDER#2"}}' \
  --update-expression 'SET expiresAt = :past, #s = :pending, createdAt = :now, total = :t' \
  --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{
    ":past":{"N":"'"$(date -u -d '1 hour ago' +%s)"'"},
    ":pending":{"S":"PENDING"},":now":{"S":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"},":t":{"N":"5"}}'
```

`expiresAt` is now an epoch-seconds timestamp in the past. **DynamoDB → Tables → Additional
settings** confirms `expiresAt` is the configured TTL attribute. The background sweep that deletes
expired items runs continuously but **is not instantaneous — AWS documents up to 48 hours**, so
this item will not visibly disappear during the lab. What you can rely on for the exam: TTL
deletions are free (no write-capacity charge), and each one appears on the stream as a `REMOVE`
event with a system identity, which is exactly what `StreamProcessorFunction` checks for to tell a
TTL expiry apart from a manual delete.

---

## Then

```bash
./labs/11-dynamodb-deep-dive/verify/checks.sh
./scripts/teardown.sh labs/11-dynamodb-deep-dive --yes
```

Teardown is under a minute — nothing here has a dependency chain like a NAT gateway or an RDS
instance.
