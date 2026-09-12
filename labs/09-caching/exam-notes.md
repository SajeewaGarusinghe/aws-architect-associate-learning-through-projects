# Exam notes — Lab 09 (Caching and performance)

Twelve SAA-C03-style questions on caching strategy, ElastiCache and private connectivity, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** A Lambda function is attached to a VPC so it can reach an ElastiCache cluster. It must also read from DynamoDB. What is the cheapest way to give it that access?

- A. A NAT gateway in a public subnet
- B. An internet gateway with a public IP on the function
- C. A DynamoDB gateway endpoint in the private route table
- D. An interface endpoint for DynamoDB in each subnet

**2.** An application caches query results in Redis with a 60-second TTL. What does the TTL primarily control?

- A. The maximum time a reader may see data that no longer matches the database
- B. How much memory the cache may use
- C. How frequently the cache replicates to its replica
- D. How long a client waits before timing out

**3.** A team needs a cache supporting replication, Multi-AZ automatic failover, sorted sets for a leaderboard, and pub/sub. Which engine fits?

- A. CloudFront
- B. Memcached
- C. DynamoDB DAX
- D. Redis

**4.** In the cache-aside pattern, what happens when the cache becomes unavailable?

- A. Writes are queued until the cache returns
- B. The application fails, because the cache is on the critical path
- C. Requests fall through to the database — slower, but still correct
- D. The database is bypassed and stale data is served

**5.** A DynamoDB-backed application needs microsecond read latency without changing application code. What should be used?

- A. ElastiCache for Redis in front of DynamoDB
- B. A CloudFront distribution over the API
- C. DynamoDB Accelerator (DAX)
- D. DynamoDB on-demand capacity

**6.** Why does attaching a Lambda function to a VPC potentially limit its concurrency?

- A. VPC functions may only run in one availability zone
- B. The VPC's route table limits concurrent connections
- C. VPC functions are capped at 100 concurrent executions
- D. Each concurrent execution needs an elastic network interface, so subnet IP space becomes a limit

**7.** Which statement about putting a Lambda function in a VPC is correct?

- A. It is required for any function handling sensitive data
- B. It should only be done when the function must reach resources that exist only in the VPC
- C. It gives the function a public IP address
- D. It improves security when calling S3 and DynamoDB

**8.** An ElastiCache node fails and the cache is empty when it returns. Every request now misses and hits the database simultaneously. What is this called, and what mitigates it?

- A. Cache poisoning — mitigated by shorter TTLs
- B. A cold start — mitigated by provisioned concurrency
- C. A thundering herd or cache stampede — mitigated by Multi-AZ replicas and staggered TTLs
- D. Cache eviction — mitigated by a larger node

**9.** Which caching layer is appropriate for caching whole HTTP responses close to end users worldwide?

- A. ElastiCache for Redis
- B. An Application Load Balancer
- C. CloudFront
- D. DynamoDB DAX

**10.** A read-heavy RDS database is CPU-saturated. The application cannot be changed to use a cache. What is the most appropriate scaling action?

- A. Enable point-in-time recovery
- B. Add read replicas and direct read traffic to them
- C. Enable Multi-AZ
- D. Increase the backup retention period

**11.** Which two AWS services support gateway VPC endpoints?

- A. DynamoDB and SQS
- B. S3 and RDS
- C. All AWS services support them
- D. S3 and DynamoDB

**12.** An ElastiCache cluster's memory fills up. What determines which items are removed?

- A. The oldest items by creation date, always
- B. The eviction policy, commonly least-recently-used among keys with a TTL
- C. Items are never removed; writes fail instead
- D. Items are moved to disk automatically

---

## Answers

**1 — C.** A **gateway endpoint is free** — it is a prefix-list route, not an ENI — and exists for exactly two services: **S3 and DynamoDB**. A NAT gateway would cost $0.059/hour to send AWS traffic out to the internet and back. Interface endpoints bill hourly per AZ. Lambda functions cannot have public IPs.

**2 — A.** The TTL is the **staleness bound** — the contract about how out of date an answer may be. Choosing it is a business decision, not a technical one: how wrong can this value be before it matters? Memory pressure is handled separately by the eviction policy.

**3 — D.** **Redis** supports replication, Multi-AZ failover, persistence, transactions and rich data structures including sorted sets and pub/sub. **Memcached** is a simple multi-threaded key/value cache with no persistence, replication or failover. Leaderboards, pub/sub and high availability all point to Redis.

**4 — C.** In cache-aside the application checks the cache and falls back to the system of record on a miss — so a cache outage costs **latency and a burst of database load, never data**. A cache whose failure takes the service down is not a cache; it is a dependency, and that is a design error.

**5 — C.** **DAX** is a DynamoDB-specific, write-through cache that is API-compatible with DynamoDB, so it requires essentially no code change and delivers microsecond reads. ElastiCache would work but requires implementing cache-aside yourself. On-demand capacity is a billing mode and changes nothing about latency.

**6 — D.** A VPC-attached function runs behind ENIs in your subnets, and those consume IP addresses. Undersized subnets therefore become a hard ceiling on concurrency — a genuine production surprise. Modern Lambda shares ENIs far more efficiently than it once did, but address planning still matters.

**7 — B.** S3, DynamoDB, SQS and most AWS services are **not in your VPC**, and a function calling them is no safer inside one. Attaching a VPC costs internet access (unless you add NAT), consumes ENIs and subnet addresses, and adds complexity. Do it only to reach RDS, ElastiCache or other VPC-only resources.

**8 — C.** An empty cache sending every request to the database at once is a **thundering herd**. Mitigations: a replica with automatic failover so the cache is never wholly lost, jittered TTLs so entries do not expire together, and request coalescing so only one caller repopulates a given key.

**9 — C.** **CloudFront** caches HTTP responses at roughly 600 edge locations, close to users. ElastiCache caches arbitrary application data beside the application, in one region. DAX caches DynamoDB items specifically. Load balancers distribute requests; they do not cache.

**10 — B.** **Read replicas** add read capacity — that is precisely what they are for. Multi-AZ adds a standby that serves no traffic and solves availability, not scale. Directing reads at replicas still requires an application or proxy change, but it is the only listed option that adds capacity.

**11 — D.** Gateway endpoints exist only for **S3 and DynamoDB**. They are free, implemented as prefix-list routes in a route table rather than as network interfaces, and cannot be reached from on-premises over VPN or Direct Connect. Every other service uses interface endpoints (PrivateLink), which bill hourly per AZ but do work over Direct Connect.

**12 — B.** The **eviction policy** decides — typically `volatile-lru` (least recently used among keys that have a TTL) or `allkeys-lru`. A cluster with no eviction policy and no free memory will start rejecting writes, which looks like an application bug rather than a capacity problem.

---

## The traps, condensed

1. **Gateway endpoints are free and exist only for S3 and DynamoDB.** If a VPC resource talks to
   either, this is almost always the intended answer over a NAT gateway.
2. **Only put Lambda in a VPC to reach VPC-only resources.** "For security" is wrong — S3, DynamoDB
   and SQS are not in your VPC, and the attachment costs internet access and ENIs.
3. **A cache failure must cost latency, not availability.** Cache-aside falls through to the system
   of record; if it cannot, you built a dependency.
4. **TTL is a staleness contract**, chosen by the business, not by the cache.
5. **Redis for replication, failover, persistence, sorted sets, pub/sub. Memcached for simple,
   multi-threaded, horizontally scaled caching.**
6. **DAX for DynamoDB microsecond reads with no code change.**
7. **Read replicas add read capacity; Multi-AZ does not.** The standby serves nothing.
8. **An empty cache is a thundering herd.** Replicas, jittered TTLs and request coalescing mitigate it.
9. **ElastiCache bills by the hour whether or not anything uses it.** It is a server, unlike Lambda
   or DynamoDB on-demand.

## Reference — which cache, and where

| Layer | Caches | Latency | Reach for it when |
|---|---|---|---|
| **CloudFront** | Whole HTTP responses at the edge | ms, near the user | Static content, global audience |
| **API Gateway caching** | API responses per stage | ms | Repeated identical API calls; bills hourly |
| **ElastiCache** | Arbitrary application data | sub-ms in-region | Query results, sessions, computed values |
| **DAX** | DynamoDB items, transparently | **microseconds** | DynamoDB reads with no code change |
| **Read replicas** | Nothing — adds capacity | same as primary | Read scaling for a relational database |

## Reference — Redis vs Memcached

| | Redis | Memcached |
|---|---|---|
| Data structures | Strings, hashes, lists, sets, sorted sets, streams | Strings only |
| Replication | **Yes** | No |
| Multi-AZ failover | **Yes** | No |
| Persistence / snapshots | **Yes** | No |
| Pub/sub, transactions, Lua | **Yes** | No |
| Multi-threaded | No (mostly) | **Yes** |
| Scale by | Node size, replicas, cluster mode shards | Adding nodes |

Exam shorthand: leaderboards, pub/sub, persistence or HA → **Redis**. Simplicity and horizontal
scaling of a plain cache → **Memcached**.

## Reference — VPC endpoints

| | Gateway endpoint | Interface endpoint (PrivateLink) |
|---|---|---|
| Services | **S3 and DynamoDB only** | Most AWS services, plus partner and your own |
| Implemented as | A route in a route table | An ENI with a private IP |
| Cost | **Free** | ~$0.013/hr per AZ + per GB |
| From on-premises (VPN/DX) | **No** | **Yes** |
| Security groups apply | No | Yes |

## Reference — caching strategies

| Strategy | How it works | Trade-off |
|---|---|---|
| **Cache-aside (lazy loading)** | App checks cache, on miss reads DB and populates | Only cached data is requested data; first read is always a miss |
| **Write-through** | App writes to cache and DB together | Cache always warm; you store data nobody reads |
| **Write-behind** | Write to cache, flush to DB asynchronously | Fast writes; risk of loss before the flush |
| **TTL on everything** | Entries expire on a timer | Bounds staleness; causes periodic miss bursts unless jittered |
