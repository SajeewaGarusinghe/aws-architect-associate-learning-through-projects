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
