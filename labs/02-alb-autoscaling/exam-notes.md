# Exam notes — Lab 02 (ALB + Auto Scaling)

Twelve SAA-C03-style questions on load balancing, scaling and the elasticity story, then the
traps and reference tables. Answers are at the bottom — try them cold first.

---

## Questions

**1.** An Auto Scaling group runs four instances behind an Application Load Balancer. On one
instance the web server process crashes, but the operating system keeps running normally. The
load balancer stops sending it traffic, yet the Auto Scaling group never replaces it and capacity
stays reduced for hours. What is the cause?

- A. The health check grace period is too long
- B. The Auto Scaling group's health check type is `EC2` rather than `ELB`
- C. The target group's deregistration delay is too short
- D. The minimum size of the Auto Scaling group is set too low

**2.** A web tier in private subnets must accept traffic only from an Application Load Balancer.
Instances are replaced frequently by an Auto Scaling group, and a third availability zone will be
added later. What inbound rule on the web tier's security group best meets this?

- A. Allow TCP 80 from the VPC CIDR block
- B. Allow TCP 80 from the CIDR blocks of the public subnets
- C. Allow TCP 80 with the load balancer's security group as the source
- D. Allow TCP 80 from the load balancer's private IP addresses

**3.** Users report `503 Service Temporarily Unavailable` from an Application Load Balancer. The
EC2 instances behind it are running and their EC2 status checks pass. What does a 503 from an ALB
most directly indicate?

- A. The target returned a malformed response
- B. The target did not respond within the timeout
- C. There are no healthy targets registered in the target group
- D. The load balancer's security group is blocking inbound traffic

**4.** An application behind an Application Load Balancer logs the source IP of every request for
audit purposes. After migrating behind the ALB, every logged address belongs to the VPC's private
range. How should the application obtain the real client IP?

- A. Enable Proxy Protocol v2 on the target group
- B. Read the `X-Forwarded-For` request header
- C. Switch the target group's target type to `ip`
- D. Enable cross-zone load balancing

**5.** A workload needs to handle millions of requests per second with ultra-low latency, must
expose a static IP address per availability zone for a partner's firewall allow-list, and operates
over TCP rather than HTTP. Which load balancer is appropriate?

- A. Application Load Balancer
- B. Network Load Balancer
- C. Gateway Load Balancer
- D. Classic Load Balancer

**6.** A team is creating a new Auto Scaling group and wants to use mixed instance types, spot
capacity, and enforce IMDSv2. They also want to keep previous versions of the configuration so
they can roll back. What should they use?

- A. A launch configuration
- B. A launch template
- C. An AMI with the settings baked in
- D. A CloudFormation stack set

**7.** An application's CPU utilisation varies through the day. The team wants the Auto Scaling
group to keep average CPU at roughly 50% with the least configuration effort. Which scaling policy
should they choose?

- A. Simple scaling with a cooldown period
- B. Step scaling with multiple adjustment tiers
- C. Target tracking scaling
- D. Scheduled scaling

**8.** After deploying a new AMI, an Auto Scaling group begins continuously launching and
terminating instances. Each new instance is terminated a couple of minutes after launch and
replaced. The application takes about three minutes to start serving. What is the most likely
cause?

- A. The maximum size is set too low
- B. The health check grace period is shorter than the application's startup time
- C. The target group's health check interval is too long
- D. The desired capacity exceeds the maximum size

**9.** During a scale-in event, users occasionally see dropped connections as instances are
removed. The team wants in-flight requests to complete before an instance is removed from service.
Which setting controls this?

- A. The Auto Scaling group's cooldown period
- B. The target group's deregistration delay
- C. The load balancer's idle timeout
- D. The health check grace period

**10.** A web application stores user session data in memory on each EC2 instance. Users are
randomly logged out whenever the Auto Scaling group scales in. Which change best resolves this
while preserving the ability to scale horizontally?

- A. Enable sticky sessions on the target group
- B. Increase the Auto Scaling group's minimum size
- C. Move session state to ElastiCache or DynamoDB
- D. Enable scale-in protection on all instances

**11.** An architect is creating an Application Load Balancer in a VPC. What is the minimum subnet
requirement?

- A. One subnet in one availability zone
- B. Two subnets in the same availability zone
- C. Two subnets in two different availability zones
- D. One subnet per availability zone in the region

**12.** A team compares cross-zone load balancing between an ALB and an NLB for a cost-sensitive
workload. Which statement is correct?

- A. Both have it enabled by default and both charge for cross-AZ data transfer
- B. ALB has it always enabled at no additional cost; NLB has it disabled by default and charges for cross-AZ data when enabled
- C. ALB has it disabled by default; NLB has it always enabled and free
- D. Neither supports cross-zone load balancing without a Global Accelerator

---

## Answers

**1 — B.** The default health check type, `EC2`, watches only hypervisor-level status checks — it
sees a healthy host and does nothing. `ELB` makes the group inherit the target group's verdict, so
a failed *application* triggers replacement, not just a failed host. **The target group decides who
receives traffic; the Auto Scaling group decides who exists — and they only agree when health
check type is `ELB`.** A shorter deregistration delay (C) affects draining, not detection.

**2 — C.** A security group can name another security group as its source. The permission then
follows the load balancer itself rather than any address range, so it survives instance
replacement, subnet renumbering, and the new AZ. The VPC CIDR (A) admits every resource in the
network. Subnet CIDRs (B) break when subnets change. ALB private IPs (D) are not stable — AWS
changes them as the load balancer scales.

**3 — C.** An ALB returns **503 when it has no healthy target** to forward to. **502** means a
target returned a malformed or unparseable response; **504** means the target did not answer within
the timeout. Knowing which code means what is worth memorising — the exam uses them as the whole
clue. Note that instances passing EC2 status checks says nothing about whether they pass the
*target group's* health check.

**4 — B.** An ALB terminates the client connection and opens a new one to the target, so the
source IP the target sees is the load balancer's. The original client address is preserved in the
`X-Forwarded-For` header (along with `X-Forwarded-Proto` and `X-Forwarded-Port`). Proxy Protocol
v2 (A) is the **NLB** answer, not ALB. An NLB with target type `instance` preserves the source IP
natively — which is a common reason to choose one.

**5 — B.** Network Load Balancer: layer 4, millions of requests per second, single-digit
millisecond latency, one static IP per AZ (and optional Elastic IPs), and it preserves the source
IP. The ALB (A) is layer 7 and has no static IP. Gateway Load Balancer (C) is for inserting
third-party virtual appliances such as firewalls. Classic (D) is legacy and should never be a
correct answer on a current exam.

**6 — B.** Launch **templates** are versioned and support every current EC2 feature, including
mixed instance policies, Spot, placement groups and metadata options such as requiring IMDSv2.
Launch **configurations** are the deprecated predecessor: immutable, unversioned, and unable to
express most of these. If a question mentions versioning, rollback, mixed instances or Spot, the
answer is a launch template.

**7 — C.** Target tracking is the simplest: name a metric and a target value ("average CPU at
50%") and AWS manages the scaling activity. Step scaling (B) applies different adjustments based
on how far the metric has breached — more control, more configuration. Simple scaling (A) is the
older single-adjustment-with-cooldown model. Scheduled scaling (D) suits predictable time-based
patterns, not variable load.

**8 — B.** The **health check grace period** is how long the Auto Scaling group waits after launch
before health checks count against an instance. If it is shorter than the application's startup
time, every new instance is killed before it can pass its first check, and the group launches
another — an **infinite replacement loop that bills for every instance**. Set the grace period
comfortably above real startup time. "ASG constantly cycling instances" is the exam's signature
phrasing for this.

**9 — B.** The target group's **deregistration delay** — also called connection draining — is how
long the load balancer lets in-flight requests finish before removing a target. Default 300
seconds, configurable 0–3600. Cooldown (A) governs how soon the *next* scaling activity may start;
idle timeout (C) is about how long an idle connection is held open.

**10 — C.** Externalising session state to ElastiCache or DynamoDB makes the tier genuinely
stateless, so any instance can serve any request and horizontal scaling works properly. Sticky
sessions (A) are a workaround that pins users to one instance — the session is still lost when
that instance goes away, and load distributes unevenly. Scale-in protection (D) prevents scaling
from doing its job.

**11 — C.** An ALB requires **at least two subnets in two different availability zones**. That
requirement is precisely what makes an ALB inherently multi-AZ, and it is why this lab has two
public subnets even though only the load balancer uses them.

**12 — B.** For an **ALB**, cross-zone load balancing is always on, cannot be disabled at the load
balancer level, and incurs **no** cross-AZ data charge. For an **NLB** it is **off by default**,
and enabling it means paying for cross-AZ data transfer. This asymmetry is a favourite
cost-optimisation question.

---

## The traps, condensed

1. **`EC2` health check type sees healthy hosts, not healthy applications.** Whenever a question
   describes a broken app that the load balancer stopped using but the ASG never replaced, this is
   the answer.
2. **Grace period shorter than startup time = infinite replacement loop.** Signature phrase:
   "instances are constantly being terminated and relaunched".
3. **Security groups can reference security groups.** Almost always the best answer for
   tier-to-tier permission, beating any CIDR-based rule.
4. **503 = no healthy targets. 502 = bad response from target. 504 = target timed out.**
5. **ALB hides the client IP** (use `X-Forwarded-For`); **NLB preserves it**. This alone sometimes
   determines the right load balancer.
6. **Launch configurations are deprecated.** Any question involving versioning, Spot, or mixed
   instance types points to a launch template.
7. **Target tracking is the default right answer** for "maintain a metric at a value with least
   effort".
8. **Sticky sessions are a workaround, not a fix.** Externalise session state instead.
9. **Cross-zone: ALB always on and free; NLB off by default and charged.**

## Reference — choosing a load balancer

| | Application LB | Network LB | Gateway LB |
|---|---|---|---|
| Layer | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) | 3 (IP) |
| Routes on | Path, host, header, query, method | Protocol and port | All traffic to appliances |
| Client IP | Replaced; see `X-Forwarded-For` | **Preserved** | Preserved |
| Static IP | No (DNS name only) | **Yes**, one per AZ; Elastic IPs supported | Via endpoints |
| Latency | Milliseconds | **Single-digit milliseconds** | Depends on appliance |
| Cross-zone | Always on, free | Off by default, charged | Off by default |
| Typical use | Web apps, microservices, containers | Extreme throughput, TCP, static IPs | Firewalls, IDS/IPS |

## Reference — Auto Scaling settings that get tested

| Setting | Default | What it actually controls |
|---|---|---|
| Health check type | `EC2` | Whether app-level failures trigger replacement. **Set to `ELB`.** |
| Health check grace period | 300 s | How long after launch before health checks count |
| Deregistration delay | 300 s | How long in-flight requests get to finish (target group setting) |
| Cooldown | 300 s | How soon the next scaling activity may begin |
| Termination policy | Default | Rebalances AZs first, then oldest launch template version |
| Scale-in protection | Off | Prevents an instance being chosen for termination |
