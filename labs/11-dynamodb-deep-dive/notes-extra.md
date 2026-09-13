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
