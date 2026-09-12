# Exam notes — Lab 01 (VPC from scratch)

Twelve SAA-C03-style questions drawn from what this lab builds, then the traps and the
reference tables worth memorising. Answers are at the bottom — try them cold first.

---

## Questions

**1.** An EC2 instance launches into a subnet with an auto-assigned public IPv4 address. Its
security group allows all outbound traffic and the subnet uses the default network ACL. The
instance still cannot reach the internet. What is the most likely cause?

- A. The instance needs an Elastic IP instead of an auto-assigned public IP
- B. The subnet's route table has no `0.0.0.0/0` route to an internet gateway
- C. The instance needs a NAT gateway to reach the internet
- D. DNS hostnames are disabled on the VPC

**2.** Instances in a private subnet cannot complete outbound HTTPS requests — connections hang
and time out. The security group allows TCP 443 outbound. A custom network ACL on the subnet
allows TCP 443 outbound, and inbound allows all traffic from `10.0.0.0/16` only. What fixes it?

- A. Add an inbound rule for TCP 443 to the security group
- B. Add an inbound network ACL rule allowing TCP 1024–65535 from `0.0.0.0/0`
- C. Add an outbound rule for ephemeral ports to the security group
- D. Replace the custom network ACL with the default network ACL

**3.** Private instances download several terabytes per month from Amazon S3, currently routed
through a NAT gateway. Which change reduces cost the most?

- A. Create an interface endpoint for S3
- B. Create a gateway endpoint for S3
- C. Move the instances to a public subnet
- D. Add a second NAT gateway to spread the load

**4.** A security policy forbids any internet path from a private subnet — no NAT gateway, no
internet gateway route. Administrators must still get an interactive shell on the instances via
Session Manager. Which VPC interface endpoints are required?

- A. `ssm` only
- B. `ssm` and `ec2`
- C. `ssm`, `ssmmessages` and `ec2messages`
- D. `ssm`, `ssmmessages` and `s3`

**5.** An architecture places one NAT gateway in the public subnet of AZ-a. Private subnets in
both AZ-a and AZ-b use a single route table pointing at it. AZ-a suffers a full outage. What
happens to instances in AZ-b's private subnet?

- A. They continue normally; NAT gateways are regional
- B. They lose outbound internet connectivity
- C. They automatically fail over to an internet gateway
- D. They lose all connectivity, including to other subnets in the VPC

**6.** How many usable IP addresses does a `10.20.11.0/24` subnet provide for EC2 instances?

- A. 256
- B. 254
- C. 251
- D. 250

**7.** Two VPCs must exchange traffic. VPC-A uses `10.0.0.0/16` and VPC-B uses `10.0.0.0/24`.
What is the outcome of creating a VPC peering connection?

- A. It succeeds; the more specific route wins
- B. It succeeds, but only one direction works
- C. It fails — peered VPCs cannot have overlapping CIDR blocks
- D. It succeeds if a transit gateway is used instead

**8.** Instances with only IPv6 addresses in a private subnet need to download OS updates from
the internet, but nothing on the internet may initiate a connection to them. What provides this?

- A. A NAT gateway
- B. An egress-only internet gateway
- C. An internet gateway with a restrictive network ACL
- D. A NAT instance with source/destination checking disabled

**9.** A security team enables VPC Flow Logs at the VPC level with `TrafficType: ALL`. Which
traffic will **not** appear in the logs?

- A. Rejected inbound SSH attempts
- B. Traffic between two instances in different subnets of the same VPC
- C. Requests to the instance metadata service at `169.254.169.254`
- D. Outbound HTTPS traffic to the internet through a NAT gateway

**10.** A single malicious IP address is attacking a public-facing application. The team wants to
block that one address at the subnet boundary while allowing all other traffic. What should they use?

- A. A security group inbound deny rule
- B. A network ACL inbound deny rule
- C. A security group with the IP removed from the allow list
- D. An egress-only internet gateway

**11.** A workload requires that the device performing network address translation be protected
by a security group, and the same device must also serve as a bastion host. Which option meets
both requirements?

- A. A NAT gateway
- B. A NAT instance
- C. An egress-only internet gateway
- D. An internet gateway

**12.** A development VPC has a NAT gateway that processes essentially no traffic outside of
business hours. The team is surprised by the monthly bill. Why?

- A. NAT gateways bill per connection, and idle connections still count
- B. NAT gateways bill an hourly charge regardless of traffic, plus a per-GB data processing charge
- C. The Elastic IP is billed at a premium when attached to a NAT gateway
- D. NAT gateways bill a minimum of 1 TB of data processing per month

---

## Answers

**1 — B.** A public IP address does nothing on its own. A subnet is "public" only because its
route table sends `0.0.0.0/0` to an internet gateway; that route is the entire definition. An
Elastic IP (A) would change nothing, since a public IP is already assigned. A NAT gateway (C) is
for instances *without* public IPs in private subnets. DNS hostnames (D) affect name resolution,
not reachability.

**2 — B.** Network ACLs are **stateless**: they evaluate each packet in each direction
independently. The reply to an outbound HTTPS request arrives as a new inbound packet on an
ephemeral port (1024–65535), so it needs its own inbound rule. The security group needs nothing
(A, C) because it is **stateful** — it admits replies to allowed outbound traffic automatically.
D would work but is a blunt instrument that discards the intended subnet-level controls.

**3 — B.** Gateway endpoints for S3 and DynamoDB are **free** and remove both the NAT data
processing charge ($0.0059/GB) and the NAT hourly cost for that traffic. An interface endpoint
(A) also keeps traffic off the NAT gateway but bills hourly *and* per GB, so it is more expensive
here. C breaks the security posture; D increases cost.

**4 — C.** Session Manager needs all three: `ssm` (the service API), `ssmmessages` (the
Session Manager data channel) and `ec2messages` (the agent's command channel). Missing any one
leaves the instance showing as not managed. Add the S3 gateway endpoint too if you need session
logging to S3 — but it is not required for the session itself.

**5 — B.** A NAT gateway is **zonal**, not regional. A single NAT in AZ-a is a single point of
failure for every private subnet routed through it, and traffic from AZ-b also incurs cross-AZ
data transfer charges in normal operation. The resilient pattern is one NAT gateway per AZ, with
a separate route table per AZ. D is wrong because the `local` route keeps intra-VPC traffic working.

**6 — C.** A `/24` has 256 addresses. AWS reserves **five** in every subnet: network address
(`.0`), VPC router (`.1`), DNS (`.2`), reserved for future use (`.3`), and broadcast (`.255`).
That leaves **251**. The classic wrong answer is 254, which is the on-premises networking answer.

**7 — C.** Peered VPCs cannot have overlapping or matching CIDR blocks — the connection request
fails outright. This is why CIDR planning matters before you build: it cannot be changed later
without rebuilding. (It is also why this lab used `10.20.0.0/16`, avoiding the `10.0.0.0/16`
already in use.) A transit gateway (D) does not solve overlapping CIDRs either.

**8 — B.** An egress-only internet gateway is the IPv6 equivalent of a NAT gateway: outbound-only,
stateful, horizontally scaled, and **free**. NAT gateways (A) handle IPv4 only. IPv6 addresses are
globally routable, so an ordinary internet gateway (C) would make the instances inbound-reachable.

**9 — C.** Flow logs do not capture traffic to the instance metadata service (`169.254.169.254`),
traffic to the Amazon DNS server, DHCP traffic, Windows license activation, or traffic to the
reserved VPC router address. They *do* capture rejected traffic (A), intra-VPC traffic (B), and
NAT-bound traffic (D).

**10 — B.** Security groups support **allow rules only** — there is no deny. Blocking a specific
source address requires a network ACL, which supports both allow and deny and is evaluated in
rule-number order, lowest first, with the first match winning.

**11 — B.** A NAT **instance** is an ordinary EC2 instance, so it can have a security group and
can double as a bastion host. A NAT **gateway** supports neither — it cannot be associated with a
security group (only the subnet's network ACL applies to it) and cannot serve as a bastion. The
trade-off: NAT instances need manual HA, patching, and source/destination checking disabled.

**12 — B.** A NAT gateway bills roughly **$0.059/hour in `ap-southeast-2` whether or not a single
packet crosses it** — about **$43/month idle** — plus $0.0059 per GB processed. This is the most
common cause of unexpected charges in a personal AWS account, and the reason this lab verifies
teardown with a tag sweep rather than trusting `DELETE_COMPLETE`.

---

## The traps, condensed

1. **A public IP does not make a subnet public.** The route table does. If the exam describes an
   instance with a public IP that cannot reach the internet, look at the route table first.
2. **Stateful vs stateless is the highest-yield distinction in this domain.** Symptoms of a
   missing ephemeral-port NACL rule: outbound connections that hang or time out while the
   security group is obviously correct.
3. **Security groups cannot deny.** Any question about blocking a specific IP is a NACL question.
4. **NAT gateways are zonal.** "Highly available NAT" always means one per AZ.
5. **Gateway endpoints are free; interface endpoints are not.** If a question optimises cost for
   S3 or DynamoDB traffic, gateway endpoint is the answer. For any other service it is an
   interface endpoint, and the cost is the trade-off you accept for private connectivity.
6. **Overlapping CIDRs can never be peered.** Not with peering, not with transit gateway.
7. **Five reserved IPs per subnet, always.** 251 usable in a `/24`, not 254.
8. **Session Manager beats a bastion** on almost every exam question involving secure access:
   no inbound rule, no key pair, no public IP, IAM-authenticated and CloudTrail-logged.

## Reference — security group vs network ACL

| | Security group | Network ACL |
|---|---|---|
| Operates at | Elastic network interface | Subnet boundary |
| State | **Stateful** — replies auto-allowed | **Stateless** — each direction evaluated separately |
| Rules | Allow only | Allow **and** deny |
| Evaluation | All rules evaluated together | Lowest rule number first, first match wins |
| Default (new custom) | Denies all inbound, allows all outbound | Denies everything until rules are added |
| Default (created with VPC) | — | Allows all inbound and outbound |
| Applies to | Instances you associate it with | Every instance in the associated subnets |

## Reference — the ways out of a VPC

| Component | Direction | IP version | Cost | Notes |
|---|---|---|---|---|
| Internet gateway | Both | IPv4 + IPv6 | Free | 1:1 NAT for instances that have a public IP |
| NAT gateway | Outbound only | IPv4 | ~$0.059/hr + $0.0059/GB | Zonal; no security group; scales to 100 Gbps |
| NAT instance | Outbound only | IPv4 | EC2 pricing | Supports security groups; can be a bastion; manual HA |
| Egress-only internet gateway | Outbound only | IPv6 | Free | The IPv6 counterpart to a NAT gateway |
| Gateway endpoint | To AWS service | IPv4 | **Free** | S3 and DynamoDB only; a route, not an ENI |
| Interface endpoint | To AWS service | IPv4 | ~$0.013/hr per AZ + per GB | An ENI with private DNS; works over Direct Connect and VPN |
