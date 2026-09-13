# Exam notes — Lab 11 (DynamoDB Deep Dive)

Twelve SAA-C03-style questions on partition design, indexes, capacity modes, consistency, transactions and Streams, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** A table uses customerId as the partition key. One customer places far more orders than any other, and that customer's requests start getting throttled while the table's overall consumed capacity is well under its provisioned limit. What is happening?

- A. DynamoDB requires manual partition rebalancing that has not been triggered yet
- B. The item size for that customer's items exceeds 400 KB
- C. A hot partition — traffic to one partition key exceeds that partition's share of throughput, regardless of the table-wide total
- D. The table needs a global secondary index

**2.** A table's access pattern is entirely unpredictable — sometimes zero requests for hours, sometimes a burst of thousands per second with no warning. Which billing mode fits best, and why?

- A. Provisioned capacity with auto scaling, because it reacts to the burst
- B. Provisioned capacity with reserved capacity purchased in advance
- C. On-demand, because it charges per request with no capacity to plan for and scales instantly to bursts
- D. On-demand cannot handle sudden bursts, so provisioned is required

**3.** A table has partition key orderId. A new requirement needs 'every order placed by a given customer, newest first' — a query that doesn't exist today. What is the standard fix?

- A. Scan the table and filter by customerId in application code
- B. Change the base table's partition key to customerId
- C. Add a local secondary index with customerId as its partition key
- D. Add a global secondary index with customerId as its partition key and a timestamp as its sort key

**4.** Which statement correctly distinguishes a local secondary index from a global secondary index?

- A. A GSI is limited to five per table; an LSI has no such limit
- B. An LSI must be created when the table is created and shares the base table's partition key; a GSI can be added or removed at any time with its own partition key
- C. A GSI must be created when the table is created; an LSI can be added later
- D. An LSI supports strongly consistent reads and a GSI does not — otherwise they are interchangeable

**5.** An UpdateItem call includes ConditionExpression 'stock > :zero'. Concurrent requests hit the same item when stock is already 0. What happens?

- A. The first request succeeds and all others are silently dropped
- B. Every request whose condition fails returns ConditionalCheckFailedException immediately, and the item is left unchanged
- C. All requests succeed and stock goes negative
- D. The requests are queued and retried automatically by DynamoDB until stock becomes positive

**6.** An application needs to create an order and decrement matching stock, and must never end up with one write applied and not the other. Which DynamoDB feature fits?

- A. Two separate PutItem/UpdateItem calls wrapped in a try/except block
- B. DynamoDB Streams, replaying the order write from the change log
- C. BatchWriteItem, which applies all items in the batch as a single unit
- D. TransactWriteItems, which applies up to 100 actions across one or more tables as a single all-or-nothing operation

**7.** A DynamoDB table has Streams enabled with view type NEW_AND_OLD_IMAGES, feeding a Lambda function via an event source mapping. An item is deleted because its TTL attribute expired. What does the Lambda function see?

- A. A REMOVE event carrying the item's last image, distinguishable from a manual delete by a system principal in the record
- B. The function is not invoked because TTL deletions are asynchronous
- C. Nothing — TTL deletions do not appear on the stream
- D. An INSERT event, because TTL creates a tombstone record

**8.** A query against a table's base table returns stale results immediately after a write completes on a different node handling that request. What read type was used, and how would this be avoided?

- A. Eventually consistent reads cannot be made consistent without switching to a global table
- B. The behavior is a bug; DynamoDB reads are always immediately consistent by default
- C. Eventually consistent read, the default; request ConsistentRead=true for a strongly consistent read, at roughly double the read capacity cost
- D. Strongly consistent read used by default; disable it to avoid staleness

**9.** A read-heavy DynamoDB table backs a product catalog with the same handful of items read far more often than everything else. Latency needs to drop from single-digit milliseconds to microseconds. What should be added?

- A. DAX (DynamoDB Accelerator) as an in-memory cache in front of the table, requiring no application logic changes for cached reads
- B. Enable DynamoDB Streams and cache reads in the Lambda function
- C. A global secondary index on the most-read attribute
- D. Switch the table to provisioned capacity with a higher RCU value

**10.** An application must remain available for both reads and writes even if an entire AWS Region becomes unavailable, with automatic multi-active replication and no manual failover step. What DynamoDB feature provides this?

- A. A read replica in a second region, promoted manually during an outage
- B. Global tables — multi-region, multi-active replication with typically sub-second propagation and no application-triggered failover
- C. Point-in-time recovery restored into a second region after an outage
- D. On-demand backups copied cross-region on a schedule

**11.** A nightly batch job scans an entire 50 GB table to build a report, and the team wants to eliminate the throughput impact of that scan on the table's normal traffic without changing the report's logic. What is the most direct fix?

- A. Increase provisioned RCUs permanently to absorb the scan
- B. Export the table to Amazon S3 (DynamoDB's built-in export feature) and run the report against the export instead of scanning the live table
- C. Convert the Scan to a Query, which does not consume read capacity
- D. Run the same Scan against a read replica of the table

**12.** A provisioned-capacity table is set to 100 WCU. A write pattern averages 60 WCU but bursts to 300 WCU for one minute every hour, and the team wants to avoid both throttling during the burst and paying for 300 WCU around the clock. What should be configured?

- A. Application auto scaling on the table's WCU, with a target utilization and min/max bounds, so capacity rises for the burst and falls back afterward
- B. Provision a flat 300 WCU permanently to guarantee the burst is never throttled
- C. Enable DynamoDB Accelerator (DAX) to absorb the write burst
- D. Switch to on-demand billing, which is always cheaper for any bursty pattern

---

## Answers

**1 — C.** Throughput is spread across partitions, not just across the table. A single very active partition key can be throttled even when the table overall has capacity to spare — this is a **hot partition**. Adaptive capacity and on-demand mode both help absorb it, but the durable fix is a partition key with higher cardinality, such as adding a random or time-based suffix to spread the load.

**2 — C.** **On-demand** bills per request and scales immediately, which is exactly suited to unpredictable, spiky traffic. Provisioned capacity with auto scaling reacts on a delay — it adjusts based on consumption metrics, so a sudden burst can be throttled before scaling catches up. Provisioned capacity is the better economic choice only once traffic is steady enough to forecast.

**3 — D.** A **GSI** can have an entirely different partition key from the base table, which is exactly what's needed here. An **LSI is not an option** — it must share the base table's partition key. Changing the base table's key schema isn't possible after creation, and Scan-and-filter reads (and bills for) the whole table.

**4 — B.** The creation-time constraint is the detail the exam leans on hardest: an **LSI** can only be declared when the table is created, is limited to five per table, and always shares the base table's partition key with a different sort key. A **GSI** can be added or removed on a live table, has its own partition and sort key, and supports up to twenty per table by default. The consistency point is real but reversed as a distinguishing feature — LSIs optionally support strongly consistent reads; GSIs are eventually consistent only.

**5 — B.** A condition expression makes the check and the write one atomic operation. Any call where the condition evaluates false gets **ConditionalCheckFailedException** back immediately and makes no change — there is no queueing or retry built in. This is the standard way to prevent overselling or lost updates without a separate locking service.

**6 — D.** **TransactWriteItems** is the only one of these that is genuinely atomic across multiple items — all actions succeed together or none do. **BatchWriteItem is a common trap**: despite the name, it makes independent per-item writes and a partial failure can leave some items written and others not. It roughly doubles the consumed write capacity compared to the same writes done individually, which is the cost of the atomicity guarantee.

**7 — A.** TTL deletions are **free of write-capacity charge** but still appear on the stream as an ordinary **REMOVE** event, carrying the old image. The record identifies the deletion as coming from the DynamoDB service rather than a user or role, which is how a consumer tells a TTL expiry apart from an application-issued delete.

**8 — C.** DynamoDB defaults to **eventually consistent reads**, which cost half the read capacity of a strongly consistent read and may briefly reflect stale data after a very recent write. Passing **ConsistentRead=true** (GetItem, Query, Scan) requests a strongly consistent read from the leader, at double the RCU cost — and it is not available at all against a global secondary index.

**9 — A.** **DAX** is a managed, write-through, in-memory cache purpose-built for DynamoDB, cutting read latency from milliseconds to microseconds for cached items with minimal code change (the DAX client is API-compatible with the DynamoDB SDK). A GSI changes what you can query, not how fast a repeated read returns; more RCUs raise throughput ceilings, not latency for hot items.

**10 — B.** **Global tables** replicate a table across chosen regions with active-active reads and writes in every region — there is no primary to fail over, and no manual promotion step. PITR and on-demand backups protect against data loss and corruption, not regional unavailability, and DynamoDB has no concept of a manually promoted read replica the way RDS does.

**11 — B.** DynamoDB's **export to S3** reads from the table's continuous backups rather than consuming the table's provisioned or on-demand capacity, so a full-table analytical job can run against the export with zero impact on live traffic. DynamoDB has no concept of a read replica; a Query still consumes capacity and only helps if the access pattern fits a single partition, which a full-table report does not.

**12 — A.** **Application auto scaling** on provisioned capacity adjusts WCU/RCU within configured bounds based on a target utilization metric, which is exactly the tool for a predictable but bursty pattern under provisioned billing. It reacts on a short delay rather than instantly, unlike on-demand — but on-demand isn't automatically cheaper here since the average load is only 60 WCU most of the time. Provisioning a flat 300 WCU eliminates throttling risk but pays for unused capacity the rest of the hour. DAX accelerates reads, not writes.

---

## The traps, condensed

1. **BatchWriteItem is not atomic.** Despite the name, each item is written independently — a
   partial failure can leave some written and others not. Only `TransactWriteItems` gives
   all-or-nothing across multiple items, at roughly double the write-capacity cost.
2. **An LSI is a table-creation-time decision.** Cannot be added later, capped at five per table,
   and must share the base table's partition key. A GSI has none of those restrictions — add or
   remove it any time, its own partition key, up to twenty per table by default.
3. **A GSI is always eventually consistent.** `ConsistentRead=true` is not available against a
   global secondary index at all, only against the base table or an LSI.
4. **Scan reads the whole table and bills for it, no matter what it returns.** Any access pattern
   that isn't "I know the partition key" needs an index, not a Scan.
5. **`status` — like `name`, `count`, `data` and `timestamp` — is a DynamoDB reserved word.** Using
   it directly in a key condition or update expression fails with a validation error; it must be
   aliased through `ExpressionAttributeNames` (`#s` → `status`). This trips up this exact lab's GSI
   the first time anyone queries it, which is the point of hitting it here rather than in an exam.
6. **A hot partition throttles even when the table has spare capacity.** Throughput is a per-partition
   resource; one overloaded partition key throttles independently of the table-wide total. Fix the
   key design (add a suffix to spread load), don't just raise capacity.
7. **TTL deletions are free and appear on Streams as a REMOVE**, distinguishable from a manual
   delete by the system principal in the record. Deletion isn't instant — AWS documents up to 48
   hours for the background sweep.
8. **DAX accelerates reads, not writes**, and only helps items that are actually re-read from
   cache. It does not change what you can query — that's a GSI's job.
9. **Global tables are multi-active, not primary/replica.** There is no failover step because
   there is no primary to fail over from. PITR and on-demand backups protect against data loss and
   corruption; they do not provide regional availability.
10. **Export to S3 bypasses the table's throughput entirely** — it reads from continuous backups,
   so a full-table analytical job costs nothing against the live table's capacity.
11. **Auto scaling on provisioned capacity reacts on a delay.** For a burst that must never
    throttle even for a few seconds, on-demand or a higher floor beats waiting on a scaling policy.

## Reference — GSI vs LSI

| | Global secondary index | Local secondary index |
|---|---|---|
| Partition key | Any attribute | Must match the base table's |
| Sort key | Any attribute | A different attribute from the base table's sort key |
| Created | Any time | **Only at table creation** |
| Limit per table | 20 (default, raisable) | 5 |
| Consistency | Eventually consistent only | Eventually or strongly consistent |
| Capacity | Its own (provisioned mode) | Shares the base table's |

## Reference — read and write operations

| Operation | Reads/writes | Cost grows with | Atomic across items? |
|---|---|---|---|
| `GetItem` / `PutItem` | One item by full key | Item size | N/A — single item |
| `Query` | One partition, optionally ranged | Items **returned** | N/A — single partition |
| `Scan` | **Every item in the table** | Total **table size** | N/A |
| `BatchGetItem` / `BatchWriteItem` | Up to 100 items / 25 items | Items processed | **No** — per-item independent results |
| `TransactGetItems` / `TransactWriteItems` | Up to 100 items, one or more tables | ~2x the equivalent plain operation | **Yes** — all or nothing |

## Reference — capacity modes

| | On-demand | Provisioned |
|---|---|---|
| Pricing | Per request | Per hour, for reserved WCU/RCU |
| Best fit | Spiky, unpredictable, new/unknown traffic | Steady, forecastable traffic |
| Scaling | Instant | Auto scaling reacts with a short delay |
| Throttling risk | Very low (up to double recent peak instantly) | Depends on headroom and scaling policy |

## Reference — this table's design

| Item type | pk | sk | Appears in gsi1-status-by-time? | Appears in lsi1-by-total? |
|---|---|---|---|---|
| Product | `PRODUCT#<id>` | `PRODUCT#<id>` | No — no `status` attribute | No — no `total` attribute |
| Order | `CUSTOMER#<id>` | `ORDER#<id>` | Yes — has `status` + `createdAt` | Yes — has `total` |
| Audit record | `AUDIT` | `<epoch-ms>#<eventId>` | No | No |

Three completely different item shapes, one table, each index picking up only the items that carry
its key attributes — this is what "sparse index" and "single-table design" mean in practice, not
just in the abstract.
