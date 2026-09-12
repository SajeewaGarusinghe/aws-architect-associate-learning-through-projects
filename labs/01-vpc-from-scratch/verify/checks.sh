#!/usr/bin/env bash
# Read-only. Asserts the deployed reality matches what docs/architecture.html claims.
# Creates nothing, changes nothing, costs nothing.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh

PASS=0; FAIL=0
check() { # check "label" "expected" "actual"
  if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1))
  else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi
}
F=("Name=tag:Project,Values=$TAG_PROJECT")

hdr "Comparing the live account against the architecture document"

VPC=$(aws ec2 describe-vpcs --filters "${F[@]}" --query 'Vpcs[0].VpcId' --output text)
[[ "$VPC" == "None" || -z "$VPC" ]] && die "no lab VPC found — is the stack deployed?"

check "VPC CIDR is 10.20.0.0/16" "10.20.0.0/16" \
  "$(aws ec2 describe-vpcs --vpc-ids "$VPC" --query 'Vpcs[0].CidrBlock' --output text)"
check "DNS hostnames enabled (interface endpoints need it)" "True" \
  "$(aws ec2 describe-vpc-attribute --vpc-id "$VPC" --attribute enableDnsHostnames --query 'EnableDnsHostnames.Value' --output text)"
check "four subnets" "4" \
  "$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query 'length(Subnets)' --output text)"
check "subnets span two AZs" "2" \
  "$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query 'length(Subnets[].AvailabilityZone)' --output text >/dev/null; aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" --query 'Subnets[].AvailabilityZone' --output text | tr '\t' '\n' | sort -u | wc -l)"

hdr "Routing — the only thing that makes a subnet public"
PUB_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" \
  --query 'RouteTables[?Routes[?GatewayId!=`null` && starts_with(GatewayId, `igw-`)]].RouteTableId | [0]' --output text)
PRIV_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" \
  --query 'RouteTables[?Routes[?NatGatewayId!=`null`]].RouteTableId | [0]' --output text)
[[ "$PUB_RT"  != "None" ]] && { ok "public route table $PUB_RT sends 0.0.0.0/0 to an internet gateway"; PASS=$((PASS+1)); } \
                           || { bad "no route table with an igw default route"; FAIL=$((FAIL+1)); }
[[ "$PRIV_RT" != "None" ]] && { ok "private route table $PRIV_RT sends 0.0.0.0/0 to a NAT gateway"; PASS=$((PASS+1)); } \
                           || { bad "no route table with a NAT default route"; FAIL=$((FAIL+1)); }
S3PL=$(aws ec2 describe-route-tables --route-table-ids "$PRIV_RT" \
  --query 'RouteTables[0].Routes[?DestinationPrefixListId!=`null`].DestinationPrefixListId' --output text 2>/dev/null)
[[ -n "$S3PL" ]] && { ok "S3 gateway endpoint present as prefix-list route ($S3PL) — not an ENI"; PASS=$((PASS+1)); } \
                 || { bad "no S3 prefix-list route on the private route table"; FAIL=$((FAIL+1)); }

hdr "Egress paths"
check "exactly one NAT gateway" "1" \
  "$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" --query 'length(NatGateways[?State==`available`])' --output text)"
NATIP=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[?State==`available`]|[0].NatGatewayAddresses[0].PublicIp' --output text)
ok "NAT gateway public address: $NATIP  ← the instance should report this as its source IP"
check "three interface endpoints" "3" \
  "$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC" --query 'length(VpcEndpoints[?VpcEndpointType==`Interface` && State==`available`])' --output text)"

hdr "The stateful / stateless pair"
SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" "Name=group-name,Values=*sg-app*,*AppSecurityGroup*" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
[[ "$SG" == "None" || -z "$SG" ]] && SG=$(aws ec2 describe-instances --filters "${F[@]}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
check "app security group has zero inbound rules (stateful — replies need none)" "0" \
  "$(aws ec2 describe-security-groups --group-ids "$SG" --query 'length(SecurityGroups[0].IpPermissions)' --output text)"
NACL=$(aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$VPC" "Name=default,Values=false" \
  --query 'NetworkAcls[0].NetworkAclId' --output text)
EPH=$(aws ec2 describe-network-acls --network-acl-ids "$NACL" \
  --query 'NetworkAcls[0].Entries[?RuleNumber==`120` && Egress==`false`].PortRange.From' --output text 2>/dev/null)
check "custom NACL rule 120 opens ephemeral ports inbound (stateless — replies need this)" "1024" "$EPH"

hdr "Compute and observability"
INST=$(aws ec2 describe-instances --filters "${F[@]}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
check "instance has NO public IP" "None" \
  "$(aws ec2 describe-instances --instance-ids "$INST" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
check "instance reachable by Session Manager" "Online" \
  "$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INST" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)"
check "flow logs active on the VPC" "ACTIVE" \
  "$(aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$VPC" --query 'FlowLogs[0].FlowLogStatus' --output text)"

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m — the doc and reality disagree.\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
