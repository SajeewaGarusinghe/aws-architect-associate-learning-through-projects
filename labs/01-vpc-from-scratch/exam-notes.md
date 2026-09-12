# Exam notes — Lab 01 (VPC from scratch)

Twelve SAA-C03-style questions drawn from what this lab builds, then the traps and the reference tables worth memorising. Answers are at the bottom — try them cold first.

---

## Questions

**1.** An EC2 instance launches into a subnet with an auto-assigned public IPv4 address. Its security group allows all outbound traffic and the subnet uses the default network ACL. The instance still cannot reach the internet. What is the most likely cause?

- A. The instance needs a NAT gateway to reach the internet
- B. DNS hostnames are disabled on the VPC
- C. The instance needs an Elastic IP instead of an auto-assigned public IP
- D. The subnet's route table has no `0.0.0.0/0` route to an internet gateway

**2.** Instances in a private subnet cannot complete outbound HTTPS requests — connections hang and time out. The security group allows TCP 443 outbound. A custom network ACL allows TCP 443 outbound, and inbound allows all traffic from `10.0.0.0/16` only. What fixes it?

- A. Add an inbound rule for TCP 443 to the security group
- B. Add an outbound rule for ephemeral ports to the security group
- C. Add an inbound network ACL rule allowing TCP 1024–65535 from `0.0.0.0/0`
- D. Replace the custom network ACL with the default network ACL

**3.** Private instances download several terabytes per month from Amazon S3, currently routed through a NAT gateway. Which change reduces cost the most?

- A. Create an interface endpoint for S3
- B. Move the instances to a public subnet
- C. Create a gateway endpoint for S3
- D. Add a second NAT gateway to spread the load

**4.** A security policy forbids any internet path from a private subnet — no NAT gateway, no internet gateway route. Administrators must still get an interactive shell via Session Manager. Which VPC interface endpoints are required?

- A. `ssm`, `ssmmessages` and `s3`
- B. `ssm` and `ec2`
- C. `ssm` only
- D. `ssm`, `ssmmessages` and `ec2messages`

**5.** One NAT gateway sits in the public subnet of AZ-a. Private subnets in both AZ-a and AZ-b share a single route table pointing at it. AZ-a suffers a full outage. What happens to instances in AZ-b's private subnet?

- A. They lose outbound internet connectivity
- B. They lose all connectivity, including to other subnets in the VPC
- C. They automatically fail over to an internet gateway
- D. They continue normally; NAT gateways are regional

**6.** How many usable IP addresses does a `10.20.11.0/24` subnet provide for EC2 instances?

- A. 250
- B. 251
- C. 256
- D. 254

**7.** Two VPCs must exchange traffic. VPC-A uses `10.0.0.0/16` and VPC-B uses `10.0.0.0/24`. What is the outcome of creating a VPC peering connection?

- A. It succeeds, but only one direction works
- B. It succeeds; the more specific route wins
- C. It succeeds if a transit gateway is used instead
- D. It fails — peered VPCs cannot have overlapping CIDR blocks

**8.** Instances with only IPv6 addresses in a private subnet need to download OS updates from the internet, but nothing on the internet may initiate a connection to them. What provides this?

- A. A NAT gateway
- B. An egress-only internet gateway
- C. An internet gateway with a restrictive network ACL
- D. A NAT instance with source/destination checking disabled

**9.** A security team enables VPC Flow Logs at the VPC level with `TrafficType: ALL`. Which traffic will *not* appear in the logs?

- A. Requests to the instance metadata service at `169.254.169.254`
- B. Rejected inbound SSH attempts
- C. Traffic between two instances in different subnets of the same VPC
- D. Outbound HTTPS traffic to the internet through a NAT gateway

**10.** A single malicious IP address is attacking a public-facing application. The team wants to block that one address at the subnet boundary while allowing all other traffic. What should they use?

- A. An egress-only internet gateway
- B. A security group with the IP removed from the allow list
- C. A security group inbound deny rule
- D. A network ACL inbound deny rule

**11.** A workload requires that the device performing network address translation be protected by a security group, and that the same device also serve as a bastion host. Which option meets both requirements?

- A. A NAT gateway
- B. A NAT instance
- C. An internet gateway
- D. An egress-only internet gateway

**12.** A development VPC has a NAT gateway that processes essentially no traffic outside business hours. The team is surprised by the monthly bill. Why?

- A. NAT gateways bill per connection, and idle connections still count
- B. NAT gateways bill an hourly charge regardless of traffic, plus a per-GB data processing charge
- C. The Elastic IP is billed at a premium when attached to a NAT gateway
- D. NAT gateways bill a minimum of 1 TB of data processing per month

---

## Answers

**1 — D.** A public IP does nothing on its own. A subnet is **public only because its route table sends `0.0.0.0/0` to an internet gateway** — that route is the entire definition. An Elastic IP changes nothing when a public IP is already assigned, a NAT gateway serves instances *without* public IPs, and DNS hostnames affect name resolution rather than reachability.

**2 — C.** Network ACLs are **stateless** — each packet is evaluated in each direction independently. The reply to an outbound HTTPS request arrives as a new inbound packet on an ephemeral port (1024–65535) and needs its own rule. The security group needs nothing because it is **stateful**. Replacing the ACL would work but discards the intended subnet controls.

**3 — C.** Gateway endpoints for S3 and DynamoDB are **free**, and remove both the NAT hourly cost and the $0.0059/GB data processing charge for that traffic. An interface endpoint also bypasses NAT but bills hourly *and* per GB. Moving to a public subnet breaks the security posture; a second NAT increases cost.

**4 — D.** All three are needed: `ssm` for the service API, `ssmmessages` for the Session Manager data channel, and `ec2messages` for the agent's command channel. Miss any one and the instance never shows as managed. An S3 gateway endpoint is needed only if you want session logs written to S3.

**5 — A.** A NAT gateway is **zonal**, not regional. A single NAT is a single point of failure for every private subnet routed through it — and in normal operation AZ-b's traffic also pays a cross-AZ transfer charge. The resilient pattern is one NAT per AZ with a route table per AZ. Intra-VPC traffic keeps working via the `local` route.

**6 — B.** A `/24` holds 256 addresses and AWS reserves **five** in every subnet: network (`.0`), VPC router (`.1`), DNS (`.2`), reserved for future use (`.3`), and broadcast (`.255`). That leaves **251**. The tempting wrong answer is 254 — the on-premises networking answer.

**7 — D.** Peered VPCs cannot have overlapping or matching CIDR blocks; the request fails outright. A transit gateway does not solve it either. This is why CIDR planning matters *before* you build — it cannot be changed later without a rebuild, and it is exactly why this lab chose `10.20.0.0/16`.

**8 — B.** An egress-only internet gateway is the IPv6 counterpart to a NAT gateway: outbound-only, stateful, horizontally scaled and **free**. NAT gateways and NAT instances handle IPv4 only. IPv6 addresses are globally routable, so a plain internet gateway would leave the instances inbound-reachable.

**9 — A.** Flow logs exclude traffic to the instance metadata service, the Amazon DNS server, DHCP, Windows license activation, and the reserved VPC router address. They *do* capture rejected traffic, intra-VPC traffic, and NAT-bound traffic — the `ACCEPT`/`REJECT` field is your evidence of which control dropped a packet.

**10 — D.** Security groups support **allow rules only** — there is no deny. Blocking a specific source requires a network ACL, which supports allow and deny and is evaluated in rule-number order, lowest first, first match wins. Any exam question about blocking one IP is a NACL question.

**11 — B.** A NAT **instance** is an ordinary EC2 instance, so it can carry a security group and double as a bastion. A NAT **gateway** supports neither — only the subnet's network ACL applies to it. The trade-off is that NAT instances need manual HA, patching, and source/destination checking disabled.

**12 — B.** A NAT gateway bills roughly **$0.059/hour whether or not a single packet crosses it** — about **$43/month idle** — plus $0.0059 per GB processed. It is the most common cause of surprise charges in a personal AWS account, and the reason this lab verifies teardown with a tag sweep instead of trusting `DELETE_COMPLETE`.

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
