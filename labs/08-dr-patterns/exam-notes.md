# Exam notes — Lab 08 (DR patterns)

Twelve SAA-C03-style questions on recovery objectives, DR strategies and DNS routing, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** A business states it can tolerate four hours of downtime but must not lose more than five minutes of data. Which pair of objectives does this describe?

- A. Both RTO and RPO are 4 hours
- B. RTO 4 hours, RPO 5 minutes
- C. RTO 5 minutes, RPO 4 hours
- D. RTO 4 hours, with no RPO requirement

**2.** A company replicates its database continuously to a second region but keeps all application servers switched off there. In a disaster they start the servers and redirect traffic. Which DR strategy is this?

- A. Multi-site active/active
- B. Backup and restore
- C. Warm standby
- D. Pilot light

**3.** A Route 53 failover record has a TTL of 3600 seconds. The health check detects failure in 60 seconds. What is the realistic worst-case recovery time for an already-connected client?

- A. Up to roughly 61 minutes, because cached answers persist for the TTL
- B. About 60 seconds
- C. Immediate, because Route 53 pushes updates to resolvers
- D. About 30 minutes, half the TTL

**4.** Which Route 53 routing policy sends users to the region that gives them the lowest response time?

- A. Weighted
- B. Geoproximity
- C. Latency-based
- D. Geolocation

**5.** An engineer accidentally deletes rows from a DynamoDB table at 14:30. Point-in-time recovery is enabled. What can they do?

- A. Nothing — PITR only protects against infrastructure failure
- B. Restore only from the most recent daily snapshot
- C. Restore to a new table as it existed at any second within the last 35 days
- D. Undo the deletion in place on the existing table

**6.** Which statement about enabling S3 versioning and DynamoDB PITR is correct?

- A. Versioning is retroactive but PITR is not
- B. Both must be enabled before the incident — they cannot recover data lost beforehand
- C. Both are enabled by default on new resources
- D. Both can be enabled after an incident to recover prior data

**7.** A Route 53 health check monitors an endpoint that returns 200 from a load balancer even when the database behind it is failing. What is the consequence?

- A. Route 53 fails over as soon as user requests error
- B. The health check keeps passing, failover never triggers, and the outage continues
- C. The health check times out and triggers failover
- D. CloudWatch automatically overrides the health check

**8.** Which DR strategy has the lowest RTO, and what is the trade-off?

- A. Pilot light — near-zero RTO, at minimal cost
- B. Warm standby — zero RTO with no additional cost
- C. Backup and restore — lowest cost and lowest RTO
- D. Multi-site active/active — near-zero RTO, at roughly double the running cost

**9.** An application needs a relational database with cross-region disaster recovery, an RPO of about one second, and promotion of the secondary region in under a minute. What fits?

- A. RDS cross-region read replica
- B. Aurora Global Database
- C. RDS Multi-AZ
- D. DynamoDB global tables

**10.** What is the purpose of an S3 delete marker in a versioned bucket?

- A. It marks the object for lifecycle transition to Glacier
- B. It becomes the current version so the object appears deleted, while prior versions remain
- C. It prevents the object from being deleted
- D. It permanently erases all versions of the object

**11.** A company wants to centrally define and enforce backup schedules and retention across EC2, EBS, RDS, DynamoDB and EFS. Which service is designed for this?

- A. AWS Config
- B. Amazon S3 lifecycle policies
- C. AWS Backup
- D. Amazon Data Lifecycle Manager

**12.** Which Route 53 routing policy would you use to send 10% of traffic to a new version of an application?

- A. Failover
- B. Weighted
- C. Multivalue answer
- D. Geolocation

---

## Answers

**1 — B.** **RTO is how long you are down** — four hours here. **RPO is how much data you may lose** — five minutes. They are bought separately: a relaxed RTO permits a cheap strategy like pilot light, while a tight RPO demands continuous replication regardless.

**2 — D.** **Pilot light**: the core data is always replicated and ready, but compute is off until needed. Recovery takes tens of minutes to start and scale. **Warm standby** keeps a scaled-down copy actually running. **Backup and restore** has nothing replicated continuously.

**3 — A.** Detection plus caching. Route 53 changes its answer after ~60 seconds, but resolvers that already answered keep serving the old value **until their cached TTL expires** — up to an hour. The TTL is a floor on recovery time you set in advance, which is why failover records use short TTLs.

**4 — C.** **Latency-based** routing uses measured latency between the user and AWS regions. **Geolocation** routes by where the user is, which is about compliance and localisation rather than speed. **Geoproximity** routes by distance with an adjustable bias. **Weighted** splits by proportion, for canaries and migrations.

**5 — C.** PITR restores **to a new table** — never in place — at any second within the trailing 35 days. Note that it protects against *application* errors as much as infrastructure failure; a bad deploy writing garbage is the common case. The restore target being a new table means cutover is a deliberate step.

**6 — B.** Neither is retroactive. Versioning starts preserving versions from the moment it is switched on; PITR starts its continuous backup window then too. **Turning them on after the mistake recovers nothing** — which is why recovery point is a decision made long before the disaster, and why neither being on by default is worth knowing.

**7 — B.** A health check only knows what the checked path tells it. A shallow check on `/` that does not touch the failing dependency **keeps passing while the application is broken**, so failover never happens. The check must exercise the dependency you are actually worried about — the same lesson as ALB health checks in Lab 02.

**8 — D.** **Multi-site active/active** serves live traffic from both regions, so recovery is effectively immediate — and you pay for full capacity in both, plus the hardest engineering problem: keeping data consistent when both sides accept writes. RTO and cost trade against each other across all four strategies.

**9 — B.** **Aurora Global Database** replicates cross-region with typically sub-second lag and promotes a secondary region in about a minute. RDS Multi-AZ is single-region and solves AZ failure only. A cross-region read replica works but has higher lag and slower manual promotion. DynamoDB global tables are excellent but not relational.

**10 — B.** A delete on a versioned bucket inserts a **delete marker** as the new current version. The object appears gone, but every prior version still exists and still bills. Removing the marker restores the object — and this is also why a versioned bucket is not truly empty when teardown tries to delete it.

**11 — C.** **AWS Backup** centralises backup plans, schedules, retention and cross-region copy across many services, with vaults and compliance reporting. Data Lifecycle Manager handles EBS snapshots only. Config reports on configuration compliance but takes no backups.

**12 — B.** **Weighted** routing splits traffic by assigned proportions — the standard mechanism for canary releases and gradual migrations. Failover is active/passive. Multivalue returns up to eight healthy answers and is a poor substitute for a load balancer. Geolocation routes by user location.

---

## The traps, condensed

1. **RTO is downtime; RPO is data loss.** They are bought separately. "Hours of downtime is fine but
   no data loss" is a cheap RTO with an expensive RPO.
2. **TTL is a floor on recovery time.** Route 53 can change its answer in 60 seconds and still leave
   clients on a dead endpoint for an hour if the TTL says so.
3. **A shallow health check never fails over.** If the checked path does not touch the broken
   dependency, the outage just continues.
4. **Versioning and PITR are not retroactive.** Enabling them after the incident recovers nothing.
5. **PITR restores to a new table**, never in place. The same is true of RDS point-in-time restore.
6. **A delete marker is a version.** A versioned bucket is not empty when objects look deleted.
7. **Untested standby = no standby.** The most expensive DR failure is failing over to something
   that does not work.
8. **Aurora Global Database** is the answer for relational, cross-region, sub-second RPO, ~1 minute
   promotion.

## Reference — the four DR strategies

| Strategy | RTO | RPO | Running cost | Shape |
|---|---|---|---|---|
| Backup and restore | Hours–days | Hours | Lowest | Backups only; build on demand |
| Pilot light | Tens of minutes | Minutes | Low | Data replicated, compute off |
| Warm standby | Minutes | Seconds–minutes | Medium | Scaled-down copy running |
| Multi-site active/active | Near zero | Near zero | Highest | Both regions serving live |

Match the strategy to the stated objectives — a question naming a tolerable downtime is telling you
which row to pick.

## Reference — Route 53 routing policies

| Policy | Chooses by | Typical use |
|---|---|---|
| Simple | Nothing | One answer, no logic |
| **Failover** | Health check | Active/passive DR — this lab |
| **Weighted** | Assigned proportion | Canary releases, gradual migration |
| **Latency** | Measured latency | Send users to the fastest region |
| Geolocation | User's location | Compliance, localisation |
| Geoproximity | Distance, with bias | Shift traffic between regions gradually |
| Multivalue | Up to 8 healthy answers | Crude client-side spreading, not a load balancer |

Route 53 is the only AWS service with a **100% availability SLA**. Health checks cost $0.50/month
for AWS endpoints, hosted zones $0.50/month.

## Reference — recovery mechanisms by service

| Service | Mechanism | Window |
|---|---|---|
| S3 | Versioning + MFA delete; Object Lock for WORM | Until versions expire |
| DynamoDB | Point-in-time recovery; on-demand backups | **35 days** continuous |
| RDS | Automated backups → point-in-time restore | **0–35 days** (0 disables) |
| RDS / Aurora | Manual snapshots | Until deleted |
| Aurora | Backtrack (in place, rewinds the cluster) | Up to 72 hours |
| EBS | Snapshots, incremental to S3 | Until deleted |
| Many services | AWS Backup, centrally governed | Per plan |
