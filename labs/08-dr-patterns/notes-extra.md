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
