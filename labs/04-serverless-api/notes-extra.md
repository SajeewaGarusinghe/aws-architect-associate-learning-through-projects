## The traps, condensed

1. **Read the traffic pattern before choosing serverless.** *Spiky, unpredictable, intermittent,
   infrequent* → Lambda. *Steady, sustained, high volume* → EC2 or containers, because per-request
   pricing stops being cheaper.
2. **Scan reads the whole table and bills for all of it.** Any filtering on a non-key attribute is
   a Scan unless you add a global secondary index.
3. **15 minutes is the hard Lambda ceiling.** A long batch job rules Lambda out — Fargate, Batch,
   ECS or Step Functions instead.
4. **Reserved concurrency caps; provisioned concurrency warms.** They sound similar and do opposite
   things. Provisioned concurrency bills hourly and surrenders zero-idle-cost.
5. **Init code runs once per execution environment, not per request.** Move expensive setup outside
   the handler.
6. **Execution role = what the function may do. Resource policy = who may invoke it.** Both appear
   on the exam, often in the same question.
7. **429 is throttling, not failure.** Concurrency limit reached.
8. **An undeclared Lambda log group never expires.** Declare it with explicit retention.
9. **API keys, usage plans, request validation or WAF → REST API.** Otherwise HTTP API, which is
   cheaper and faster.
10. **Lambda needs a VPC only to reach private resources** such as an RDS instance. Attaching one
    for "security" adds cost and cold-start latency while buying nothing, since S3, DynamoDB and
    most AWS services are not in your VPC anyway.

## Reference — HTTP API vs REST API

| | HTTP API | REST API |
|---|---|---|
| Price per million | ~$1.00 | ~$3.50 |
| Latency | Lower | Higher |
| Lambda proxy, JWT auth, CORS | Yes | Yes |
| API keys + usage plans | **No** | **Yes** |
| Request/response transformation | No | Yes |
| Request validation | No | Yes |
| WAF integration | No | Yes |
| Caching | No | Yes |
| Private endpoints | No | Yes |

## Reference — Lambda limits worth memorising

| | |
|---|---|
| Max execution time | **15 minutes** |
| Memory | 128 MB – 10,240 MB (CPU scales with it) |
| Default concurrency | 1,000 per account, per region |
| Deployment package | 50 MB zipped, 250 MB unzipped; 10 GB as a container image |
| `/tmp` space | 512 MB – 10,240 MB |
| Synchronous payload | 6 MB request and response |
| Asynchronous payload | 256 KB |

## Reference — DynamoDB access patterns

| Operation | Reads | Cost grows with | Use when |
|---|---|---|---|
| `GetItem` | One item by full primary key | Nothing | You know the exact key |
| `Query` | One partition, optionally ranged by sort key | Items **returned** | You know the partition key |
| `Scan` | **Every item in the table** | Total **table size** | Almost never |

If an access pattern needs a different key, add a **global secondary index** (different partition
and sort key, eventually consistent) or a **local secondary index** (same partition key, different
sort key, must be created with the table). Adding an index is nearly always the right answer over
switching to Scan.

## Reference — the cost contrast across the curriculum

| Lab | Idle cost per hour | What bills |
|---|---|---|
| 01 — VPC | $0.116 | NAT gateway, endpoints, instance, EIP |
| 02 — ALB + ASG | $0.052 | Load balancer and instances |
| 03 — RDS Multi-AZ | $0.078 | Database, doubled for the standby |
| **04 — Serverless** | **$0.000** | Nothing until a request arrives |

This stack would need roughly **28,000 requests an hour** to match the cost of Lab 01's NAT gateway
sitting completely idle.
