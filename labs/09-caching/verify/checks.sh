#!/usr/bin/env bash
# Read-only. Also makes two live calls against the API to measure hit vs miss.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh
PASS=0; FAIL=0
check(){ if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1));
         else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi; }

hdr "Comparing the live account against the architecture document"
C=$(aws elasticache describe-cache-clusters --cache-cluster-id saa-lab-09-redis --show-cache-node-info --query 'CacheClusters[0]' --output json 2>/dev/null)
[[ -z "$C" || "$C" == "null" ]] && die "cache cluster not found — is the stack deployed?"
check "cache is available" "available" "$(echo "$C" | jq -r '.CacheClusterStatus')"
check "engine is redis" "redis" "$(echo "$C" | jq -r '.Engine')"
check "node type is the free-tier class" "cache.t3.micro" "$(echo "$C" | jq -r '.CacheNodeType')"

hdr "No internet path, and no NAT gateway"
VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'Vpcs[0].VpcId' --output text)
check "VPC CIDR is 10.50.0.0/16" "10.50.0.0/16" \
  "$(aws ec2 describe-vpcs --vpc-ids "$VPC" --query 'Vpcs[0].CidrBlock' --output text)"
check "zero NAT gateways" "0" \
  "$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" --query 'length(NatGateways[?State!=`deleted`])' --output text)"
RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*rt-private*" --query 'RouteTables[0]' --output json)
check "no 0.0.0.0/0 route" "0" "$(echo "$RT" | jq '[.Routes[]|select(.DestinationCidrBlock=="0.0.0.0/0")]|length')"
if echo "$RT" | jq -e '.Routes[]|select(.DestinationPrefixListId!=null)' >/dev/null; then
  ok "DynamoDB gateway endpoint present as a prefix-list route (free)"; PASS=$((PASS+1))
else bad "no gateway endpoint — the function cannot reach DynamoDB"; FAIL=$((FAIL+1)); fi

hdr "Lambda is in the VPC, and Redis is reachable only from it"
FN=$(aws lambda get-function-configuration --function-name saa-lab-09-api --output json)
check "function attached to the VPC" "$VPC" "$(echo "$FN" | jq -r '.VpcConfig.VpcId')"
FNSG=$(echo "$FN" | jq -r '.VpcConfig.SecurityGroupIds[0]')
CACHESG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" "Name=tag:Name,Values=*sg-cache*" --query 'SecurityGroups[0].GroupId' --output text)
check "Redis admits the function's security group, not a CIDR" "$FNSG" \
  "$(aws ec2 describe-security-groups --group-ids "$CACHESG" --query 'SecurityGroups[0].IpPermissions[0].UserIdGroupPairs[0].GroupId' --output text)"
check "Redis port is 6379" "6379" \
  "$(aws ec2 describe-security-groups --group-ids "$CACHESG" --query 'SecurityGroups[0].IpPermissions[0].FromPort' --output text)"

hdr "Cache-aside, measured"
API=$(aws apigatewayv2 get-apis --query "Items[?Name=='saa-lab-09-api'].ApiId|[0]" --output text)
URL="https://${API}.execute-api.${AWS_REGION}.amazonaws.com?id=verify-$RANDOM"
ONE=$(curl -s -m 25 "$URL"); TWO=$(curl -s -m 25 "$URL")
S1=$(echo "$ONE" | jq -r '.source // "err"'); S2=$(echo "$TWO" | jq -r '.source // "err"')
M1=$(echo "$ONE" | jq -r '.ms // 0');        M2=$(echo "$TWO" | jq -r '.ms // 0')
if [[ "$S1" == *MISS* ]]; then ok "first call: $S1 (${M1}ms)"; PASS=$((PASS+1))
else bad "first call was '$S1', expected a miss"; FAIL=$((FAIL+1)); fi
if [[ "$S2" == *HIT* ]]; then ok "second call: $S2 (${M2}ms)"; PASS=$((PASS+1))
else bad "second call was '$S2', expected a hit"; FAIL=$((FAIL+1)); fi
awk -v a="$M1" -v b="$M2" 'BEGIN{ if (b < a) printf "  \033[1;32m✓\033[0m cache hit was faster: %.1fms vs %.1fms\n", b, a;
  else printf "  \033[1;33mWARN\033[0m hit (%.1fms) was not faster than miss (%.1fms)\n", b, a }'

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
