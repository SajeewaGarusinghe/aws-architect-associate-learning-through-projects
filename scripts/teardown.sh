#!/usr/bin/env bash
# Delete a lab stack, then prove it is gone.
#   ./scripts/teardown.sh labs/01-vpc-from-scratch          # show what would go
#   ./scripts/teardown.sh labs/01-vpc-from-scratch --yes    # delete + verify + report
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/guardrails.sh

LAB="${1:?usage: teardown.sh LAB_DIR [--yes]}"; LAB="${LAB%/}"
EXECUTE=false; [[ "${2:-}" == "--yes" ]] && EXECUTE=true

STACK="$(stack_name_for "$LAB")"
assert_lab_stack "$STACK"
verify_account

STATUS="$(stack_status "$STACK")"
[[ "$STATUS" == "DOES_NOT_EXIST" ]] && { ok "stack $STACK already gone — nothing to do"; exit 0; }

hdr "Resources in $STACK ($STATUS)"
aws cloudformation list-stack-resources --stack-name "$STACK" \
  --query 'StackResourceSummaries[].{Type:ResourceType,Id:PhysicalResourceId}' --output table

# Nothing in a lab stack may ever coincide with a protected resource.
while read -r pid; do [[ -n "$pid" ]] && assert_not_protected "$pid"; done < <(
  aws cloudformation list-stack-resources --stack-name "$STACK" \
    --query 'StackResourceSummaries[].PhysicalResourceId' --output text | tr '\t' '\n')
ok "no protected resource appears in this stack"

if ! $EXECUTE; then
  printf '\n\033[1;33mDRY RUN\033[0m — nothing deleted. To delete: ./scripts/teardown.sh %s --yes\n' "$LAB"
  exit 0
fi

hdr "Deleting $STACK"
aws cloudformation delete-stack --stack-name "$STACK"
aws cloudformation wait stack-delete-complete --stack-name "$STACK" \
  || die "delete did not complete — inspect: aws cloudformation describe-stack-events --stack-name $STACK"
END=$(date -u +%s)
ok "CloudFormation reports DELETE_COMPLETE"

# Independent confirmation: CloudFormation saying "deleted" is not the same as verifying it.
hdr "Verifying by tag sweep"
LEAKS=0
check() {
  local label="$1" count="$2"
  if [[ "$count" == "0" || -z "$count" || "$count" == "None" ]]; then ok "$label: none remaining"
  else bad "$label: $count still present"; LEAKS=$((LEAKS+1)); fi
}
check "EC2 instances"  "$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=$TAG_PROJECT" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'length(Reservations[].Instances[])' --output text)"
check "VPCs"           "$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'length(Vpcs)' --output text)"
check "NAT gateways"   "$(aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=$TAG_PROJECT" --query 'length(NatGateways[?State!=`deleted`])' --output text)"
check "Elastic IPs"    "$(aws ec2 describe-addresses --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'length(Addresses)' --output text)"
check "Load balancers" "$(aws elbv2 describe-load-balancers --query 'length(LoadBalancers)' --output text)"
check "RDS instances"  "$(aws rds describe-db-instances --query 'length(DBInstances)' --output text)"

STACK_LEFT="$(stack_status "$STACK")"
[[ "$STACK_LEFT" == "DOES_NOT_EXIST" ]] && ok "stack record removed" || { bad "stack still $STACK_LEFT"; LEAKS=$((LEAKS+1)); }

if [[ -f "$LAB/.live-state" ]]; then
  echo "END=$END" >> "$LAB/.live-state"
  ./scripts/cost-report.sh "$LAB" | tee "$LAB/teardown-report.md"
fi

if (( LEAKS > 0 )); then die "$LEAKS check(s) failed — resources may still be costing money"; fi
printf '\n\033[1;32mAccount is back to baseline.\033[0m Nothing from this lab remains.\n'
