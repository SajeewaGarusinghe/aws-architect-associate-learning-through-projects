# Console tour — Lab 09

Keep [the architecture diagram](docs/architecture.html) open. Budget ~20 minutes.

**This is the only lab since 03 with a real hourly charge** — the cache node bills whether or not
anything uses it. Deploy takes 6–9 minutes and teardown 8–12, so set a longer timer:

```bash
./scripts/auto-teardown.sh labs/09-caching 2100     # 35 minutes
```

---

## 1. Hit and miss, measured (4 min)

Take `ApiUrl` from the stack outputs and call it twice:

```bash
curl -s "$API?id=p-1" | jq
curl -s "$API?id=p-1" | jq
```

| Call | `source` | `ms` |
|---|---|---|
| First | `CACHE MISS -> DynamoDB` | larger |
| Second | `CACHE HIT` | smaller |

The gap between those two numbers is what the cache is actually buying, in the only units that
matter. Try a fresh key (`?id=p-99`) and you get a miss again — cache-aside only ever caches what
has actually been asked for.

## 2. Watch the TTL expire (2 min)

Wait 60 seconds and call the same key again. **It is a miss.** The entry was not evicted for
space; it aged out by design. That TTL is the contract about how stale an answer may be — a
business decision, not a technical one.

## 3. What the VPC changed (4 min)

Compare with Lab 04, which pointedly had no VPC.

**Lambda → `saa-lab-09-api` → Configuration → VPC** shows subnets and a security group. The
function now runs behind elastic network interfaces in your subnets.

**VPC → Route tables → `saa-lab-09-rt-private` → Routes:**

| Destination | Target |
|---|---|
| `10.50.0.0/16` | `local` |
| `pl-…` (DynamoDB prefix list) | `vpce-…` |

**No `0.0.0.0/0`.** The function has no internet access at all. The prefix-list route is the
**gateway endpoint**, and without it the function could not reach DynamoDB either — every call
would simply time out.

> The alternative is a NAT gateway at **$0.059/hour**, more than double this entire lab, to send
> AWS-service traffic out to the internet and back into AWS. Gateway endpoints are free and exist
> for exactly two services: **S3 and DynamoDB**.

**EC2 → Security Groups → `saa-lab-09-sg-cache` → Inbound**: source is the *function's* security
group, not a CIDR. Third appearance of that construct in this curriculum.

## 4. Failure injection (5 min) — remove the cache

**EC2 → Security Groups → `saa-lab-09-sg-cache` → Inbound rules → Edit → delete the 6379 rule → Save.**

Now call the API repeatedly:

```bash
for i in 1 2 3; do curl -s "$API?id=p-1" | jq -r '.source, .ms'; done
```

Every call reports `CACHE MISS`. **The API keeps working** — slower, but correct. Check
**CloudWatch → `/aws/lambda/saa-lab-09-api`** and you will see `cache unavailable` logged on each
invocation.

That is the resilience property of cache-aside: a cache failure costs latency and a burst of
database load, never data or availability. A cache whose failure takes the service down is not a
cache, it is a dependency.

Restore the rule (TCP 6379, source = the function's security group) and the hits return.

## 5. What a cache costs when nobody uses it (2 min)

**ElastiCache → Redis clusters → `saa-lab-09-redis`.** One `cache.t3.micro` node, no replica.

It has been billing at **$0.028/hour** since it was created, regardless of traffic. Unlike Lambda
and DynamoDB on-demand, a cache is a *server* — with everything that implies. A single node also
has no failover: lose it and every request misses at once, which is a thundering herd against the
database. Production would use Multi-AZ with a replica, doubling that figure.

---

## Then

```bash
./labs/09-caching/verify/checks.sh
./scripts/teardown.sh labs/09-caching --yes
```

**Teardown takes 8–12 minutes.** The cache node must be deleted, and Lambda's ENIs can take several
minutes to detach before the subnets and security groups can go. A teardown that appears stuck on a
security group is almost always waiting for an ENI — let it finish rather than deleting by hand.
