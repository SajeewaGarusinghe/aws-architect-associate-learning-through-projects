# Exam notes — Lab 04 (Serverless API)

Twelve SAA-C03-style questions on event-driven compute, NoSQL access patterns and per-request pricing, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** An internal reporting tool is used heavily for two hours each morning and sits completely idle the rest of the day. The team wants to minimise cost. Which architecture best fits?

- A. API Gateway with Lambda and DynamoDB on-demand
- B. ECS on Fargate with a minimum task count of two
- C. An Application Load Balancer in front of two reserved t3.medium instances
- D. EC2 instances in an Auto Scaling group with scheduled scaling

**2.** A DynamoDB table stores millions of orders with partition key customerId and sort key orderDate. A query retrieving one customer's orders is fast and cheap, but a report filtering all orders by status is slow and expensive. Why?

- A. The table needs provisioned capacity rather than on-demand
- B. Filtering by a non-key attribute requires a Scan, which reads every item in the table
- C. The sort key should be status rather than orderDate
- D. DynamoDB cannot filter on non-key attributes at all

**3.** A Lambda function creates a database connection object. A developer moves that creation from inside the handler to the module level, outside it. What is the effect?

- A. The connection is created once per account and shared between functions
- B. The connection is created once per request, increasing latency
- C. The connection is created once per execution environment and reused across warm invocations
- D. The function will fail because module-level code cannot make network calls

**4.** A team needs API keys with usage plans, request validation, and integration with AWS WAF. Which API Gateway type should they choose?

- A. Either — the two are functionally identical
- B. WebSocket API
- C. REST API, which supports these features
- D. HTTP API, which is cheaper and faster

**5.** A Lambda function must read from an S3 bucket. What is the correct way to give it access?

- A. Attach an execution role with an s3:GetObject policy scoped to that bucket
- B. Store IAM access keys in the function's environment variables
- C. Place the function in the same VPC as the bucket
- D. Add the function's IP address to the bucket policy

**6.** An application experiences a sudden traffic spike and some API calls return HTTP 429. The Lambda function itself is healthy and its code is unchanged. What is the most likely cause?

- A. The function timed out at 15 minutes
- B. The execution role lost its permissions
- C. The function ran out of memory
- D. Concurrent executions hit the account or reserved concurrency limit, so invocations were throttled

**7.** A team wants to eliminate cold-start latency for a latency-sensitive Lambda function. What should they use, and what is the tradeoff?

- A. Increasing the timeout — it gives the function more time to initialise
- B. Reserved concurrency — it caps cost but does not affect cold starts
- C. Provisioned concurrency — it keeps environments initialised, but bills hourly
- D. Attaching the function to a VPC — it keeps network interfaces warm

**8.** What is the maximum execution time for a single Lambda invocation?

- A. 15 minutes
- B. 5 minutes
- C. Unlimited, as long as the function reports progress
- D. 1 hour

**9.** A DynamoDB table's traffic is completely unpredictable, swinging between zero and thousands of requests per second with no pattern. Which capacity mode is appropriate?

- A. Provisioned capacity with reserved capacity purchased upfront
- B. On-demand capacity
- C. Provisioned capacity sized for the peak
- D. Provisioned capacity with auto scaling

**10.** A Lambda function returns 500 errors. CloudWatch Logs shows: "AccessDeniedException … is not authorized to perform: dynamodb:Query on resource: arn:aws:dynamodb:…:table/orders". What does this tell you?

- A. The function is not attached to the correct VPC
- B. The table does not exist
- C. DynamoDB is throttling the request
- D. The execution role's policy does not permit the Query action on that table

**11.** A Lambda function is created and invoked without an explicitly declared CloudWatch log group. What is the cost risk?

- A. Log ingestion is billed at double the normal rate
- B. Lambda creates the log group with retention set to never expire, and it accumulates storage charges indefinitely
- C. Logs are not captured at all, so failures go unnoticed
- D. Each invocation creates a new log group

**12.** How does API Gateway obtain permission to invoke a Lambda function?

- A. Both must be placed in the same VPC and security group
- B. API Gateway uses the credentials of the user who deployed the API
- C. A resource-based policy on the function grants the apigateway.amazonaws.com service principal
- D. The function's execution role includes a lambda:InvokeFunction statement

---

## Answers

**1 — A.** Serverless charges nothing while idle, which is the dominant cost factor for a workload idle 22 hours a day. The exam signals this with the words **spiky, unpredictable, intermittent or infrequent**. The corollary matters too: at sustained high volume, EC2 and provisioned capacity become cheaper again, so "steady predictable load" points the other way.

**2 — B.** A **Scan reads every item in the table** and then discards the non-matching ones — and you are billed for everything read, not for what comes back. Cost and latency grow with total table size forever. The fix is a **global secondary index** on status, which gives a Query-able access pattern. Changing the table's own sort key would break the existing query.

**3 — C.** Code outside the handler runs during the **initialisation phase**, once per execution environment — not once per request. Warm invocations reuse it, which is why moving expensive setup out of the handler is the standard Lambda optimisation. The tradeoff is that the init cost lands on the cold start instead.

**4 — C.** **REST APIs** support API keys with usage plans, request/response transformation, request validation, WAF integration, caching and private endpoints. **HTTP APIs** are roughly 70% cheaper and lower latency but omit those features. On the exam, any mention of API keys, usage plans, request validation or WAF points to REST.

**5 — A.** Lambda assumes its **execution role** and receives temporary credentials automatically — no long-lived keys should exist anywhere. Scope the policy to the specific bucket ARN rather than `s3:*` on `*`. S3 is not in a VPC, and Lambda has no stable IP address to allow-list.

**6 — D.** 429 means **throttling**. Lambda scales concurrent executions to an account limit — 1,000 by default — and a reserved concurrency setting on the function caps it lower. Timeouts surface as 502/504 and appear in the logs as a timeout; out-of-memory kills the invocation with a specific error. Fixes are raising the limit, reserved concurrency, or provisioned concurrency.

**7 — C.** **Provisioned concurrency** keeps a set number of execution environments initialised and ready, eliminating cold starts for that many concurrent invocations — but it bills for that capacity by the hour, which gives up the zero-idle-cost property that makes serverless attractive. **Reserved** concurrency does something entirely different: it caps how many concurrent executions a function may use.

**8 — A.** **15 minutes.** Any workload needing longer must move to Fargate, ECS, Batch or EC2, or be decomposed into steps coordinated by Step Functions. This limit is a common exam discriminator — a question describing a four-hour batch job is ruling Lambda out.

**9 — B.** **On-demand** charges per request with no capacity planning and absorbs sudden spikes instantly — the right fit for unpredictable traffic. Provisioned auto scaling reacts over minutes and can throttle during a sharp spike. Provisioning for peak wastes money constantly. On-demand costs more per request at steady high volume, which is when provisioned wins.

**10 — D.** An `AccessDeniedException` names three things: **who** (the assumed role), **what action** (`dynamodb:Query`) and **which resource** (the table ARN). Here the role is missing Query on that table — note that other actions such as PutItem may still work, because IAM is evaluated per action. A missing table gives ResourceNotFoundException; throttling gives ProvisionedThroughputExceededException.

**11 — B.** Lambda creates the log group implicitly on first invocation with **retention set to never expire**. Logs accumulate storage charges for the life of the account unless someone notices. Declaring the log group in the template with an explicit `RetentionInDays` — as this lab does — is the fix, and it is a genuinely common source of unexplained CloudWatch charges.

**12 — C.** A **resource-based policy** on the function grants the API Gateway service principal permission to invoke it, scoped to the specific API's ARN. This is the inverse of an execution role: the execution role says what the function may do, while the resource policy says who may call it. There is no network relationship between the two services at all.

---

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
