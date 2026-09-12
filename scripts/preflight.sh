#!/usr/bin/env bash
# Catch what a CloudFormation change set cannot.
#
# This account is on the AWS free plan, which rejects any EC2 type that is not
# free-tier eligible at RunInstances time. Neither `--dry-run` nor a change-set
# preview reports that failure: both succeed, then the real deploy fails partway
# through and rolls back - having already billed for whatever it created first.
#
#   ./scripts/preflight.sh labs/05-decoupling
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/guardrails.sh

LAB="${1:?usage: preflight.sh LAB_DIR}"; LAB="${LAB%/}"
TEMPLATE="$LAB/infra/template.yaml"
[[ -f "$TEMPLATE" ]] || die "no template at $TEMPLATE"

hdr "Preflight for $(basename "$LAB")"
ISSUES=0

# --- EC2 instance types must be free-tier eligible ---------------------------
TYPES=$(grep -oE 'InstanceType: *[a-z0-9.-]+' "$TEMPLATE" | awk '{print $2}' | sort -u)
if [[ -z "$TYPES" ]]; then
  ok "no EC2 instance types in this template"
else
  ELIGIBLE=$(aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true \
    --query 'InstanceTypes[].InstanceType' --output text 2>/dev/null | tr '\t' '\n')
  for t in $TYPES; do
    if grep -qx "$t" <<<"$ELIGIBLE"; then ok "EC2 $t is free-tier eligible"
    else bad "EC2 $t is NOT free-tier eligible — RunInstances will be rejected"; ISSUES=$((ISSUES+1)); fi
  done
fi

# --- other services have their own free-tier classes --------------------------
# These are separate APIs from RunInstances, so the EC2 restriction does not
# apply, but the sizes below are the free-tier classes and the cheapest anyway.
while read -r line; do
  [[ -z "$line" ]] && continue
  key=${line%%:*}; val=$(echo "${line#*:}" | tr -d ' ')
  case "$key" in
    DBInstanceClass)
      [[ "$val" == "db.t3.micro" || "$val" == "db.t4g.micro" ]] \
        && ok "RDS $val is the free-tier class" \
        || { warn "RDS $val is larger than the free-tier class — check the rate"; }
      ;;
    CacheNodeType)
      [[ "$val" == "cache.t3.micro" || "$val" == "cache.t4g.micro" ]] \
        && ok "ElastiCache $val is the free-tier class" \
        || { warn "ElastiCache $val is larger than the free-tier class"; }
      ;;
  esac
done < <(grep -oE '(DBInstanceClass|CacheNodeType): *[a-z0-9.]+' "$TEMPLATE" | sort -u)

# --- capacity headroom --------------------------------------------------------
VPCS=$(aws ec2 describe-vpcs --query 'length(Vpcs)' --output text)
VPCQ=$(aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE \
  --query 'Quota.Value' --output text 2>/dev/null || echo 5)
if (( VPCS < ${VPCQ%.*} )); then ok "VPC headroom: $VPCS of ${VPCQ%.*} used"
else bad "VPC quota reached: $VPCS of ${VPCQ%.*}"; ISSUES=$((ISSUES+1)); fi

if grep -q 'AWS::EC2::EIP\|NatGateway' "$TEMPLATE"; then
  EIPS=$(aws ec2 describe-addresses --query 'length(Addresses)' --output text)
  (( EIPS < 5 )) && ok "Elastic IP headroom: $EIPS of 5 used" \
                 || { bad "Elastic IP quota reached"; ISSUES=$((ISSUES+1)); }
fi

# --- template sanity ----------------------------------------------------------
if aws cloudformation validate-template --template-body "file://$TEMPLATE" >/dev/null 2>&1; then
  ok "template validates"
else bad "template failed validation"; ISSUES=$((ISSUES+1)); fi

echo
if (( ISSUES == 0 )); then printf '\033[1;32mPREFLIGHT CLEAR\033[0m — safe to deploy %s\n' "$LAB"
else printf '\033[1;31m%d blocker(s)\033[0m — fix before deploying, or the stack will roll back mid-create.\n' "$ISSUES"; exit 1; fi
