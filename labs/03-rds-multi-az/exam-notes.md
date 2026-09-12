# Exam notes — Lab 03 (RDS Multi-AZ)

Twelve SAA-C03-style questions on database availability, replication and security, then the traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** An application's RDS database is under heavy read load and the primary instance is CPU-saturated. The team enables Multi-AZ hoping to spread the reads. Performance does not improve. Why?

- A. The standby needs to be promoted before it can serve reads
- B. The Multi-AZ standby serves no traffic — it exists only for failover
- C. Multi-AZ replication is asynchronous, so the standby lags too far behind
- D. The application must be reconfigured to use the reader endpoint

**2.** During a routine RDS maintenance window, a Multi-AZ database fails over. Users see application errors for about a minute even though the database lost no data. What is the most likely explanation?

- A. The standby was not fully synchronised before the failover
- B. Failover severs open connections, and the application has no retry logic
- C. DNS caching in the application prevented it from finding the new primary
- D. Multi-AZ failover requires a manual promotion step

**3.** A company must keep its RDS database reachable only from its application tier, which runs on EC2 instances that are replaced frequently by an Auto Scaling group. What is the best way to restrict database access?

- A. A security group rule allowing 5432 from the VPC CIDR block
- B. A security group rule whose source is the application tier's security group
- C. A network ACL on the database subnets allowing only the application subnets
- D. An IAM policy restricting rds:Connect to the application role

**4.** An RDS instance was created without encryption. Compliance now requires encryption at rest. What must the team do?

- A. Enable the StorageEncrypted setting with a modify operation
- B. Take a snapshot, copy the snapshot with encryption enabled, and restore it into a new instance
- C. Enable encryption on the DB subnet group
- D. Rotate the master key in KMS, which encrypts the existing volume

**5.** Which statement about RDS read replicas is correct?

- A. They use synchronous replication and can be failed over to automatically
- B. They use asynchronous replication, can lag, and must be promoted manually
- C. They must be in the same availability zone as the primary
- D. They cannot be created in a different region from the primary

**6.** A team wants the RDS master password to exist nowhere in their CloudFormation template, deployment pipeline, or source control, and to be rotated automatically. What should they use?

- A. A CloudFormation parameter with NoEcho set to true
- B. The ManageMasterUserPassword property, which has RDS create and own a secret
- C. An SSM Parameter Store SecureString referenced by the template
- D. A hardcoded password changed manually after deployment

**7.** An RDS database has automated backups with a 7-day retention period. A developer accidentally deletes a table at 14:30. The team wants to recover the state from 14:25. What capability do they need?

- A. Restore the most recent automated snapshot
- B. Point-in-time recovery, which restores to any second within the retention period
- C. Promote the Multi-AZ standby, which retains the deleted table
- D. Restore from the read replica, which has not yet replicated the delete

**8.** A DB subnet group is being created for a single-AZ RDS instance. What is the minimum requirement?

- A. One subnet in one availability zone
- B. Subnets in at least two availability zones
- C. One private and one public subnet
- D. One subnet per availability zone in the region

**9.** A workload needs a relational database that can scale reads to fifteen replicas with sub-10ms replica lag, automatically grows storage, and fails over in under 30 seconds. Which option best fits?

- A. RDS for PostgreSQL with Multi-AZ enabled
- B. Amazon Aurora
- C. RDS for MySQL with five read replicas
- D. DynamoDB with global tables

**10.** An RDS instance is being deleted through CloudFormation. The team wants no leftover charges and no retained snapshot. Which combination achieves this?

- A. DeletionPolicy: Retain with DeleteAutomatedBackups: false
- B. DeletionPolicy: Delete with DeleteAutomatedBackups: true
- C. DeletionPolicy: Snapshot, which is always free
- D. Deleting the DB subnet group first, which cascades to the instance

**11.** A database in a private subnet has PubliclyAccessible set to false, and its route table contains only the local route. A developer asks whether they also need a NAT gateway so the database can download engine patches. What is correct?

- A. Yes — RDS instances need outbound internet access for patching
- B. No — RDS is a managed service and patches through the AWS backbone, not your VPC route table
- C. Yes, but only during the maintenance window
- D. No, but only if a VPC endpoint for RDS is created

**12.** After a Multi-AZ failover, an operations engineer checks the RDS endpoint. What has changed?

- A. The endpoint DNS name changes and clients must be reconfigured
- B. The endpoint name is unchanged; it now resolves to the promoted standby's address
- C. The endpoint keeps the same IP address, which is moved between availability zones
- D. A new endpoint is created and the old one returns errors until deleted

---

## Answers

**1 — B.** A Multi-AZ standby accepts **no connections at all**. It adds no read capacity and no throughput — you are buying a recovery time objective, nothing else. Read scaling comes from **read replicas**, which are asynchronous and do serve reads. **Multi-AZ is for availability; read replicas are for scale** — the exam tests whether you know these are different problems. There is no reader endpoint on a plain RDS instance; that is an Aurora feature.

**2 — B.** **Every failover severs every open connection.** Multi-AZ protects your data — it is not transparent at the TCP level. An application without connection retry and reconnect logic will surface errors to users during any failover, including routine patching, while the database itself is perfectly healthy throughout. Multi-AZ protects the data; only the client protects the user experience.

**3 — B.** A security group can name another security group as its source, so the permission follows the application tier rather than any address range — it keeps working as instances are replaced and subnets change. The VPC CIDR admits everything in the network. A NACL is coarser and stateless. IAM database authentication exists but is a separate feature that does not replace network controls.

**4 — B.** **Encryption must be chosen at creation.** You cannot encrypt an existing unencrypted RDS instance in place. The supported path is snapshot → copy the snapshot with encryption enabled → restore that copy as a new instance → cut over. The same restriction applies in reverse: you cannot remove encryption from an encrypted instance.

**5 — B.** Read replicas replicate **asynchronously**, which means they can lag behind the primary and may be missing recent writes at the moment you promote them — and promotion is a manual action. They can live in a different AZ *or a different region*, which makes them useful for both read scaling and cross-region disaster recovery. Synchronous, automatic failover is the Multi-AZ standby's job.

**6 — B.** `ManageMasterUserPassword: true` has RDS generate the password, create the Secrets Manager secret, own it, and rotate it — no human or template ever sees the value. `NoEcho` only hides a parameter in the console; the value still travels through the pipeline and shell history. A SecureString is better than plaintext but you still supply and rotate the initial value yourself.

**7 — B.** Automated backups enable **point-in-time recovery**: RDS combines daily snapshots with continuously archived transaction logs so you can restore to any second within the retention window, always into a *new* instance. A snapshot alone only gets you to the snapshot's moment. The standby is synchronous, so it deleted the table too. A replica would replicate the delete within seconds.

**8 — B.** A DB subnet group requires subnets in **at least two availability zones even for a single-AZ instance**. That requirement exists so that converting to Multi-AZ later — or letting RDS move the instance during recovery — is a simple modify rather than a migration. It is a small detail that appears regularly on the exam.

**9 — B.** Aurora supports up to **15 read replicas** with typically sub-10ms replica lag, a shared distributed storage layer that grows automatically to 128 TiB, and failover usually under 30 seconds. Standard RDS caps read replicas at 5 per instance with higher lag. DynamoDB is not relational, so it fails the requirement outright.

**10 — B.** `DeletionPolicy: Delete` removes the instance without retaining a final snapshot, and `DeleteAutomatedBackups: true` removes the automated backups that would otherwise persist and bill. `Retain` deliberately leaves the instance running — and billing. `Snapshot` keeps a manual snapshot, which is charged per GB beyond the free allowance and survives the stack indefinitely.

**11 — B.** RDS is managed: AWS patches the engine through its own control plane, not through your VPC's routing. A database subnet needs no NAT gateway and no internet route, which is exactly why this lab's private route table carries only the `local` route. Adding a NAT gateway here would cost $0.059/hour and buy nothing.

**12 — B.** Failover works by **repointing a DNS record**. The endpoint hostname is identical before and after; only the address it resolves to changes — in this lab, from a `10.40.11.x` in AZ-a to a `10.40.12.x` in AZ-b. No client reconfiguration is needed, though every client must reconnect because its existing connection was severed.

---

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
