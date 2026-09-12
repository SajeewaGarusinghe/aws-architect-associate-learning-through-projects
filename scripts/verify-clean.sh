#!/usr/bin/env bash
# Read-only account sweep. Run this at the start of every session: it catches
# anything a previous lab left behind before it quietly accumulates charges.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/guardrails.sh
verify_account

hdr "Account baseline — $ACCOUNT_ID / $AWS_REGION / $(date -u '+%Y-%m-%d %H:%M:%SZ')"

ISSUES=0
flag() { bad "$1"; ISSUES=$((ISSUES+1)); }

# --- lab stacks -------------------------------------------------------------
STACKS=$(aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE \
                        UPDATE_ROLLBACK_COMPLETE CREATE_IN_PROGRESS DELETE_FAILED \
  --query "StackSummaries[?starts_with(StackName, 'saa-lab-')].StackName" --output text)
[[ -z "$STACKS" ]] && ok "no lab stacks deployed" || flag "lab stacks still up: $STACKS"

# --- anything tagged as ours ------------------------------------------------
for probe in \
  "EC2 instances|$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$TAG_PROJECT" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'Reservations[].Instances[].InstanceId' --output text)" \
  "VPCs|$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'Vpcs[].VpcId' --output text)" \
  "NAT gateways|$(aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=$TAG_PROJECT" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text)" \
  ; do
  label="${probe%%|*}"; val="${probe#*|}"
  [[ -z "$val" ]] && ok "$label tagged $TAG_PROJECT: none" || flag "$label tagged $TAG_PROJECT: $val"
done

# --- untagged money-burners anywhere in the region ---------------------------
hdr "Region-wide check for billable resources"
for probe in \
  "NAT gateways|$(aws ec2 describe-nat-gateways --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text)" \
  "Load balancers|$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output text)" \
  "RDS instances|$(aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text)" \
  "Unattached EIPs|$(aws ec2 describe-addresses --query 'Addresses[?AssociationId==`null`].PublicIp' --output text)" \
  "Interface endpoints|$(aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[?VpcEndpointType==`Interface`].VpcEndpointId' --output text)" \
  ; do
  label="${probe%%|*}"; val="${probe#*|}"
  [[ -z "$val" ]] && ok "$label: none" || flag "$label: $val"
done

# --- the baseline that should always be there --------------------------------
hdr "Protected resources (must still exist)"
INST=$(aws ec2 describe-instances --instance-ids "${PROTECTED_INSTANCES[0]}" \
  --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo MISSING)
[[ "$INST" == "running" ]] && ok "session host ${PROTECTED_INSTANCES[0]} is running" \
                           || flag "session host is '$INST' — expected running"

VPCS=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text)
INSTS=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
  --query 'length(Reservations[].Instances[])' --output text)
[[ "$VPCS" == "$BASELINE_VPC_COUNT" ]] && ok "VPC count is $VPCS (baseline)" \
                                       || warn "VPC count is $VPCS, baseline is $BASELINE_VPC_COUNT"
[[ "$INSTS" == "$BASELINE_INSTANCE_COUNT" ]] && ok "running instances: $INSTS (baseline)" \
                                             || warn "running instances: $INSTS, baseline is $BASELINE_INSTANCE_COUNT"

echo
if (( ISSUES == 0 )); then
  printf '\033[1;32mCLEAN\033[0m — account is at baseline, nothing is costing money.\n'
else
  printf '\033[1;31m%d issue(s) found\033[0m — review the ✗ lines above before starting a new lab.\n' "$ISSUES"
  exit 1
fi
