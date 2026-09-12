#!/usr/bin/env bash
# Read-only. Asserts the deployed reality matches what docs/architecture.html claims.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh

PASS=0; FAIL=0
check() {
  if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1))
  else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi
}
DB=saa-lab-03-db

hdr "Comparing the live account against the architecture document"
J=$(aws rds describe-db-instances --db-instance-identifier "$DB" --query 'DBInstances[0]' --output json 2>/dev/null)
[[ -z "$J" || "$J" == "null" ]] && die "database $DB not found — is the stack deployed?"

check "database is available" "available" "$(echo "$J" | jq -r '.DBInstanceStatus')"
check "Multi-AZ is enabled" "true" "$(echo "$J" | jq -r '.MultiAZ')"
check "storage is encrypted at rest" "true" "$(echo "$J" | jq -r '.StorageEncrypted')"
check "not publicly accessible" "false" "$(echo "$J" | jq -r '.PubliclyAccessible')"
check "instance class is db.t3.micro" "db.t3.micro" "$(echo "$J" | jq -r '.DBInstanceClass')"
check "master password is RDS-managed in Secrets Manager" "true" \
  "$(echo "$J" | jq -r 'has("MasterUserSecret")')"

ENDPOINT=$(echo "$J" | jq -r '.Endpoint.Address')
PRIMARY_AZ=$(echo "$J" | jq -r '.AvailabilityZone')
STANDBY_AZ=$(echo "$J" | jq -r '.SecondaryAvailabilityZone')
ok "endpoint (unchanged by failover): $ENDPOINT"
ok "primary in $PRIMARY_AZ, standby in $STANDBY_AZ"
[[ "$PRIMARY_AZ" != "$STANDBY_AZ" && "$STANDBY_AZ" != "null" ]] \
  && { ok "primary and standby are in different AZs"; PASS=$((PASS+1)); } \
  || { bad "standby is not in a separate AZ"; FAIL=$((FAIL+1)); }

hdr "Network isolation"
check "DB subnet group spans two AZs" "2" \
  "$(echo "$J" | jq -r '[.DBSubnetGroup.Subnets[].SubnetAvailabilityZone.Name] | unique | length')"
VPC=$(echo "$J" | jq -r '.DBSubnetGroup.VpcId')
check "VPC CIDR is 10.40.0.0/16" "10.40.0.0/16" \
  "$(aws ec2 describe-vpcs --vpc-ids "$VPC" --query 'Vpcs[0].CidrBlock' --output text)"
PRIV_RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*rt-private*" \
  --query 'RouteTables[0].RouteTableId' --output text)
check "private route table has no 0.0.0.0/0 route" "0" \
  "$(aws ec2 describe-route-tables --route-table-ids "$PRIV_RT" \
     --query 'length(RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`])' --output text)"
check "zero NAT gateways" "0" \
  "$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
     --query 'length(NatGateways[?State!=`deleted`])' --output text)"

hdr "The security group chain"
DBSG=$(echo "$J" | jq -r '.VpcSecurityGroups[0].VpcSecurityGroupId')
CLIENTSG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*sg-client*" \
  --query 'SecurityGroups[0].GroupId' --output text)
check "DB SG admits the client's security group, not a CIDR" "$CLIENTSG" \
  "$(aws ec2 describe-security-groups --group-ids "$DBSG" \
     --query 'SecurityGroups[0].IpPermissions[0].UserIdGroupPairs[0].GroupId' --output text)"
check "DB SG has no CIDR-based inbound rule" "0" \
  "$(aws ec2 describe-security-groups --group-ids "$DBSG" \
     --query 'length(SecurityGroups[0].IpPermissions[0].IpRanges)' --output text)"
check "DB port is 5432" "5432" \
  "$(aws ec2 describe-security-groups --group-ids "$DBSG" \
     --query 'SecurityGroups[0].IpPermissions[0].FromPort' --output text)"

hdr "Client"
INST=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$TAG_PROJECT" \
  "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text)
check "client reachable by Session Manager" "Online" \
  "$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INST" \
     --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)"

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m — the doc and reality disagree.\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
