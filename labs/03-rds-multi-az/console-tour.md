# Console tour — Lab 03

Keep [the architecture diagram](docs/architecture.html) open beside the console. Budget about
15 minutes of observation on top of the 12–15 minute build.

**This lab's deploy is slow and the meter runs throughout.** Start it, then read the architecture
document while RDS provisions the primary and synchronises the standby.

---

## 0. While it builds (read this, don't click)

**RDS → Databases → `saa-lab-03-db`** will sit at `Creating` for 12–15 minutes. RDS creates the
primary, then builds the standby and performs an initial full sync before reporting `Available`.

This is the single slowest thing in the curriculum, and worth feeling once: highly available state
is expensive to create in a way that stateless compute is not.

## 1. Confirm it really is Multi-AZ (2 min)

**RDS → Databases → `saa-lab-03-db` → Configuration tab.**

| Look for | Expect |
|---|---|
| Multi-AZ | `Yes` |
| Availability zone | `ap-southeast-2a` (the primary) |
| Secondary zone | `ap-southeast-2b` |
| Encryption | `Enabled` |
| Publicly accessible | `No` |

On the **Connectivity & security** tab, note the **Endpoint** — a DNS name ending
`.rds.amazonaws.com`. Write it down. The entire failover test is about this name not changing.

## 2. The password nobody has seen (2 min)

**Connectivity & security tab → Master credentials → "Manage in Secrets Manager"**, or go to
**Secrets Manager → Secrets** directly.

The secret was created by RDS, not by the template. Click **Retrieve secret value** — that is the
first time any human has seen this password, and the application never will, because it fetches it
by ARN at runtime.

Check the template: `infra/template.yaml` contains `ManageMasterUserPassword: true` and no
password anywhere. Neither does CloudFormation's stored parameters, nor this git repository.

## 3. Connect (3 min)

Open a **Session Manager** shell on `saa-lab-03-client` (link from `console-links.sh`), then:

```bash
source /usr/local/bin/dbenv     # fetches the secret, sets PGHOST/PGPASSWORD
psql -c "select inet_server_addr(), version();"
```

`inet_server_addr()` returns the private address actually serving you — a `10.40.11.x`, in
AZ&nbsp;a. That is the primary.

Create something worth losing:

```bash
psql -c "create table beats (id serial primary key, at timestamptz default now());"
psql -c "insert into beats default values; select count(*) from beats;"
```

## 4. Failover (5 min) — the main event

**Start the watcher and leave it running:**

```bash
dbwatch
```

It prints the time and the serving address once a second. Let it settle, then **in a second
Session Manager tab** (or from the RDS console: **Actions → Reboot → tick "Reboot with failover"**):

```bash
aws rds reboot-db-instance --db-instance-identifier saa-lab-03-db \
  --force-failover --region ap-southeast-2
```

Now watch the first shell. The sequence:

| Time | What you see |
|---|---|
| 0 s | Normal output, address `10.40.11.x` |
| ~5 s | Connection errors begin — every open connection is severed |
| 30–90 s | Errors continue while DNS is repointed and the standby is promoted |
| ~60–120 s | Output resumes, address is now **`10.40.12.x`** |

**The three things that just happened:**

1. The endpoint hostname never changed. Only what it resolves to did.
2. The connection broke anyway. Multi-AZ is not transparent at the TCP level — an application
   without retry logic would have surfaced errors to users.
3. Nothing was lost. Confirm it:

```bash
psql -c "select count(*) from beats;"     # same count as before
```

That is synchronous replication: the commit was already durable in AZ&nbsp;b before it was
acknowledged.

**RDS → Databases → `saa-lab-03-db` → Events tab** narrates the whole thing, and Configuration now
shows the availability zones swapped.

## 5. Count the cost of the standby (1 min, optional)

**Configuration tab.** The standby is the same instance class and the same storage as the primary,
and it serves zero traffic. You are paying exactly double for a recovery time objective of about a
minute — no extra reads, no extra writes, no extra capacity.

That framing is the single most testable idea in this lab.

---

## Then, immediately

```bash
./labs/03-rds-multi-az/verify/checks.sh
./scripts/teardown.sh labs/03-rds-multi-az --yes
```

**Teardown takes about 8 minutes** — RDS must delete two instances and their automated backups.
The template sets `DeleteAutomatedBackups: true` and a `Delete` deletion policy so no final
snapshot is retained and quietly billed.
