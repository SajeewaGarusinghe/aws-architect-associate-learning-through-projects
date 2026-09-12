## The traps, condensed

1. **Multi-AZ is for availability; read replicas are for scale.** The single highest-yield sentence
   in this domain. The standby serves nothing. If a question asks about read load, Multi-AZ is
   never the answer; if it asks about surviving an AZ failure with no data loss, a replica is never
   the answer.
2. **Failover breaks every connection.** Multi-AZ is not transparent. "Users saw errors but no data
   was lost" describes a healthy failover and a client without retry logic.
3. **Encryption is a creation-time decision.** Snapshot → copy encrypted → restore is the only path
   for an existing unencrypted instance. The same applies in reverse.
4. **A DB subnet group needs two AZs even for single-AZ.** Small detail, appears regularly.
5. **Point-in-time recovery comes from automated backups**, not from snapshots, and always restores
   into a *new* instance. Retention 0 disables it entirely.
6. **RDS patches itself through the AWS backbone.** A database subnet needs no NAT gateway and no
   internet route.
7. **Aurora's numbers:** 15 read replicas, sub-10ms lag, storage auto-growing to 128 TiB, failover
   typically under 30 seconds, six copies across three AZs. Standard RDS: 5 read replicas.
8. **`ManageMasterUserPassword` is the current best-practice answer** for RDS credentials — AWS
   generates, stores and rotates, and no human ever sees the value.

## Reference — Multi-AZ vs read replica

| | Multi-AZ standby | Read replica |
|---|---|---|
| Replication | **Synchronous** | **Asynchronous** |
| Serves traffic | No — none at all | Yes, reads only |
| Failover | Automatic, ~60–120 s | Manual promotion |
| Data loss on failover | None | Possible — it may lag |
| Location | Another AZ, same region | Same AZ, another AZ, or another **region** |
| Solves | Availability | Read scaling (and cross-region DR) |
| Cost | Roughly doubles the bill | One extra instance each |
| Max count | 1 standby | 5 (RDS) / 15 (Aurora) |

## Reference — RDS backup and recovery

| Mechanism | Created by | Retention | Restores to |
|---|---|---|---|
| Automated backups | RDS, daily + transaction logs | 0–35 days (0 disables) | **Any second** in the window, into a new instance |
| Manual snapshot | You | Until deleted | The snapshot's moment, into a new instance |
| Final snapshot | RDS at deletion, if requested | Until deleted | The moment of deletion |
| Read replica | You | N/A | Promotion, with possible lag |

Backups within the retention period are free up to the size of the database; storage beyond that
bills per GB. Deleting an instance does **not** automatically delete its automated backups unless
`DeleteAutomatedBackups` is set.

## Reference — the failover timeline observed in this lab

| Elapsed | What happens |
|---|---|
| 0 s | `reboot-db-instance --force-failover` issued |
| ~5 s | Every open connection is severed |
| 30–90 s | Standby promoted; endpoint DNS record repointed |
| 60–120 s | New connections succeed against the same hostname, different address |

That interval is your real recovery time objective, and it is the number to quote when someone
asks what Multi-AZ actually buys.
