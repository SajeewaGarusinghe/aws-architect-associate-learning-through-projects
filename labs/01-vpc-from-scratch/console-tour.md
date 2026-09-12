# Console tour — Lab 01

Keep [the architecture diagram](docs/architecture.html) open beside the console. Every step
below names the thing on the diagram it corresponds to. Budget is about 12 minutes; the stack
is billing the whole time.

Run `./scripts/console-links.sh labs/01-vpc-from-scratch` for clickable deep links.

---

## 1. The resource map (2 min) — the whole diagram at once

**VPC console → Your VPCs → select the lab VPC → Resource map tab.**

This is the console's own rendering of Fig 01. Compare them directly.

- Four subnets, two per availability zone. Public subnets are the ones whose route table line
  leads to the internet gateway.
- Follow the line from `private-a` — it leads to the NAT gateway, which sits in `public-a`.
- Notice `private-b`'s line leads to the *same* NAT gateway, in the other AZ. That is the
  single point of failure the diagram calls out in the AZ-b box.

> **Ask yourself:** nothing about the subnets themselves is marked "public" or "private".
> What is actually different about them?

## 2. Route tables (3 min) — the answer to that question

**VPC → Route tables → select `saa-lab-01-rt-public` → Routes tab.**

Two rows only:

| Destination | Target |
|---|---|
| `10.20.0.0/16` | `local` |
| `0.0.0.0/0` | `igw-…` |

The `local` route is created automatically and cannot be deleted — it is why every subnet in a
VPC can always reach every other. The second row is the entire definition of "public".

**Now `saa-lab-01-rt-private` → Routes tab.** Three rows:

| Destination | Target | |
|---|---|---|
| `10.20.0.0/16` | `local` | |
| `0.0.0.0/0` | `nat-…` | outbound only — nothing can initiate inbound |
| `pl-…` (prefix list) | `vpce-…` | the S3 gateway endpoint |

That third row is worth a moment. A **gateway endpoint is a route**, not a network interface —
which is why it is free. Check the **Subnet associations** tab on each: two subnets each.

## 3. NAT gateway and the Elastic IP (2 min)

**VPC → NAT gateways.** Note the **Primary public IPv4 address**.

Then open **Systems Manager → Session Manager → Start session** and pick the lab instance
(or use the direct link from `console-links.sh`). In the shell:

```bash
curl -s https://checkip.amazonaws.com     # the address the internet sees
curl -s http://169.254.169.254/latest/meta-data/local-ipv4 \
  -H "X-aws-ec2-metadata-token: $(curl -sX PUT http://169.254.169.254/latest/api/token \
     -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')"   # the address the instance has
```

The first prints the NAT gateway's Elastic IP. The second prints a `10.20.11.x` address. That
substitution *is* network address translation.

> **Note what just happened:** you opened a root shell on a host with no public IP, no security
> group inbound rule, and no SSH key. The agent dialled out to the interface endpoints; nothing
> dialled in.

## 4. Security group vs network ACL (2 min) — the exam's favourite trap

**EC2 → Security Groups → the lab's app group → Inbound rules.**

It is **empty**. Zero inbound rules, yet your shell works and `curl` returns data. Because
security groups are **stateful**, the reply to an allowed outbound request is admitted
automatically.

**VPC → Network ACLs → the lab's custom ACL → Inbound rules.**

| Rule | Type | Source | Allow/Deny |
|---|---|---|---|
| 110 | All traffic | `10.20.0.0/16` | ALLOW |
| 120 | Custom TCP 1024–65535 | `0.0.0.0/0` | ALLOW |
| \* | All traffic | `0.0.0.0/0` | DENY |

Rule 120 exists for one reason: NACLs are **stateless**, so the reply to your outbound request
arrives as a brand-new inbound packet on an ephemeral port and needs its own rule. Rule `*` is
the implicit deny and cannot be removed.

## 5. Failure injection (3 min) — break the route, keep the shell

**Leave the Session Manager shell open.** In it, start a loop:

```bash
while true; do curl -s -m 3 -o /dev/null -w "%{http_code} " https://checkip.amazonaws.com; sleep 2; done
```

You should see a steady stream of `200`. Now, in the VPC console:

**Route tables → `saa-lab-01-rt-private` → Routes → Edit routes → delete the `0.0.0.0/0` row → Save.**

Watch the shell. The `200`s become `000` (timeouts) within seconds — **but the shell itself stays
connected.** That is the architectural point of this lab: management traffic goes to the
interface endpoints inside the VPC and never consults the default route, so it is unaffected.

Had you built this with a bastion host over the NAT gateway, you would now be locked out of the
instance you need to fix.

**Restore it:** Edit routes → Add route → `0.0.0.0/0` → NAT Gateway → the lab NAT → Save. The
`200`s return within a few seconds, without touching the instance. Press `Ctrl-C` to stop the loop.

## 6. Flow logs (1 min, optional)

**CloudWatch → Log groups → `/saa-lab-01/vpc-flow-logs`.**

Delivery lags several minutes, so records from the failure injection may not have landed yet. If
they have, the last field of each line is `ACCEPT` or `REJECT` — the only direct evidence of
which control dropped a packet.

---

## Then, immediately

```bash
./labs/01-vpc-from-scratch/verify/checks.sh      # confirm doc matches reality
./scripts/teardown.sh labs/01-vpc-from-scratch --yes
```

If you restored the route in step 5, `checks.sh` should pass every assertion. If you left it
deleted, the private-route check will fail — which is itself a demonstration that the script
actually reads the account rather than trusting the template.
