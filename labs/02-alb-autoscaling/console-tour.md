# Console tour — Lab 02

Keep [the architecture diagram](docs/architecture.html) open beside the console. Budget is about
14 minutes. Unlike Lab 01, most of this tour is watching things *change* — so read each step
before you click it.

`./scripts/console-links.sh labs/02-alb-autoscaling` prints deep links.

---

## 0. Wait for green (1 min)

Open **EC2 → Target groups → `saa-lab-02-tg` → Targets**.

Both targets start as `initial`. The health check runs every 15 seconds and needs **two
consecutive passes**, so it takes up to a minute before they turn `healthy`.

> **If you load the site now you will get a 503.** That is not a bug — it is the load balancer
> correctly refusing to send traffic to targets it has not yet verified.

## 1. The site (2 min) — load balancing made visible

Open the `SiteUrl` from the stack outputs, then **reload it repeatedly** (hard-reload if your
browser caches: Ctrl-Shift-R / Cmd-Shift-R).

The page names the availability zone and instance ID that answered. As you reload, the AZ
changes — that is round robin across the two targets. Each instance built that page at boot from
its own metadata; nothing was downloaded, because these instances have no internet access at all.

## 2. Where the public address actually is (2 min)

**EC2 → Instances →** select either lab instance.

- **Public IPv4 address:** blank.
- **Private IPv4:** `10.30.11.x` or `10.30.12.x`.

Now **EC2 → Load balancers → `saa-lab-02-alb` → Network mapping**. The ALB has a node in each
public subnet, and the DNS name resolves to both. The load balancer holds every public address in
this architecture; the fleet holds none.

**VPC → Route tables → `saa-lab-02-rt-private` → Routes.** One row: `10.30.0.0/16 → local`.
No `0.0.0.0/0` at all. These instances cannot reach the internet even if something on them tried.

## 3. The security group chain (2 min) — the exam construct

**EC2 → Security Groups → `saa-lab-02-sg-app` → Inbound rules.**

The source is not a CIDR. It is **`sg-…` — the ALB's own security group**. Click through to
confirm it is `saa-lab-02-sg-alb`.

This is why the rule never needs updating: instances are replaced constantly by the Auto Scaling
group and the permission still applies, because it follows the load balancer rather than any
address. Compare with `saa-lab-02-sg-alb`, whose inbound rule is the one place in the whole stack
that says `0.0.0.0/0`.

## 4. Failure injection A (4 min) — kill an instance

**Keep the site open in one tab and reload it every few seconds throughout this step.**

**EC2 → Instances →** select one lab instance → **Instance state → Terminate**.

Now watch three systems react, in this order:

| Where | What you see | Roughly |
|---|---|---|
| Target group → Targets | the target goes `unhealthy`, then `draining` | 15–30 s |
| The site | every reload now shows the *surviving* AZ only | immediately after draining |
| Auto Scaling group → Activity | "Launching a new EC2 instance" with a reason | 30–60 s |
| Target group → Targets | new target appears as `initial`, then `healthy` | 2–3 min total |

Two things worth noticing:

- **The site never went down.** That is the entire point of running two AZs.
- **The replacement lands in the same AZ as the one you killed.** The group rebalances to keep
  zones even rather than launching wherever is convenient.

Check **Auto Scaling groups → `saa-lab-02-asg` → Activity**. It narrates its own decisions in
plain English, including that the instance was terminated because it failed an ELB health check.

## 5. Failure injection B (3 min) — break the app, not the host

This one separates the two health-check worlds.

**EC2 → Target groups → `saa-lab-02-tg` → Health checks tab → Edit → change the path from `/` to
`/does-not-exist` → Save.**

Within about 30 seconds:

- Every target goes `unhealthy`.
- The site returns **503 Service Temporarily Unavailable** — the ALB has no healthy target to
  forward to.
- The instances themselves are running perfectly. Their EC2 status checks are green. Nothing is
  wrong with the hosts at all.

Because health check type is `ELB`, the Auto Scaling group now agrees with the target group's
verdict and starts **terminating and replacing every instance** — which will not help, since the
replacements fail the same check. Watch a cycle or two in the Activity tab.

> This is the failure mode the architecture document's red flag describes. Had health check type
> been left at the default `EC2`, the group would have seen healthy hosts and done nothing, while
> the site stayed down indefinitely.

**Restore it:** change the health check path back to `/`. Targets return to `healthy` within about
30 seconds and the site recovers.

## 6. Scale out (2 min, optional)

**Auto Scaling groups → `saa-lab-02-asg` → Edit → Desired capacity `4` → Update.**

Two instances launch, one per AZ, keeping the zones balanced. They appear in the target group and
start taking traffic once healthy. Reload the site a few times and you will see four distinct
instance IDs.

Set desired capacity back to `2` and watch the group choose which to terminate — it removes from
the AZ with the most instances first.

---

## Then, immediately

```bash
./labs/02-alb-autoscaling/verify/checks.sh          # doc vs reality
./scripts/teardown.sh labs/02-alb-autoscaling --yes
```

If you left the health check path broken, `checks.sh` will report unhealthy targets — which is the
script reading the account rather than trusting the template. Restore the path first for a clean run.

Teardown takes around four minutes: the Auto Scaling group must terminate its instances before
the subnets can be removed. **Do not terminate the instances by hand to speed it up** — the group
will simply replace them.
