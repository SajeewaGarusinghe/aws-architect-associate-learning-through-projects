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
