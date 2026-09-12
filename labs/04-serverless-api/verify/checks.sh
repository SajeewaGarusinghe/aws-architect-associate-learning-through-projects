#!/usr/bin/env bash
# Read-only. Asserts the deployed reality matches what docs/architecture.html claims.
# Also makes two live HTTP calls against the API, which cost fractions of a cent.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh

PASS=0; FAIL=0
check() {
  if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1))
  else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi
}
FN=saa-lab-04-api
TABLE=saa-lab-04-notes

hdr "Comparing the live account against the architecture document"

hdr "Compute"
J=$(aws lambda get-function-configuration --function-name "$FN" --output json 2>/dev/null)
[[ -z "$J" || "$J" == "null" ]] && die "function $FN not found — is the stack deployed?"
check "runtime is python3.12" "python3.12" "$(echo "$J" | jq -r '.Runtime')"
check "memory is 256 MB" "256" "$(echo "$J" | jq -r '.MemorySize')"
check "timeout is 10s" "10" "$(echo "$J" | jq -r '.Timeout')"
check "function is NOT attached to a VPC" "null" "$(echo "$J" | jq -r '.VpcConfig.VpcId // "null"')"
check "table name passed by environment variable" "$TABLE" \
  "$(echo "$J" | jq -r '.Environment.Variables.TABLE_NAME')"

hdr "Storage"
T=$(aws dynamodb describe-table --table-name "$TABLE" --query 'Table' --output json 2>/dev/null)
[[ -z "$T" || "$T" == "null" ]] && die "table $TABLE not found"
check "table is active" "ACTIVE" "$(echo "$T" | jq -r '.TableStatus')"
check "billing is on-demand (zero idle cost)" "PAY_PER_REQUEST" \
  "$(echo "$T" | jq -r '.BillingModeSummary.BillingMode')"
check "composite key: pk HASH + sk RANGE" "pk:HASH,sk:RANGE" \
  "$(echo "$T" | jq -r '[.KeySchema[] | "\(.AttributeName):\(.KeyType)"] | join(",")')"

hdr "Least privilege"
ROLE=$(echo "$J" | jq -r '.Role' | awk -F/ '{print $NF}')
POL=$(aws iam get-role-policy --role-name "$ROLE" --policy-name notes-table-access \
  --query 'PolicyDocument' --output json 2>/dev/null)
check "policy grants exactly 4 DynamoDB actions" "4" \
  "$(echo "$POL" | jq '[.Statement[0].Action] | flatten | length')"
check "policy is scoped to one table ARN, not '*'" "$(aws dynamodb describe-table --table-name "$TABLE" --query 'Table.TableArn' --output text)" \
  "$(echo "$POL" | jq -r '.Statement[0].Resource')"
if echo "$POL" | jq -r '[.Statement[0].Action] | flatten | .[]' | grep -q '\*'; then
  bad "policy contains a wildcard action"; FAIL=$((FAIL+1))
else ok "no wildcard actions in the policy"; PASS=$((PASS+1)); fi

hdr "Observability"
check "log group retention is 1 day, not never-expire" "1" \
  "$(aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/$FN" \
     --query 'logGroups[0].retentionInDays' --output text)"

hdr "The API actually answers"
API=$(aws apigatewayv2 get-apis --query "Items[?Name=='$FN'].ApiId|[0]" --output text)
[[ "$API" == "None" || -z "$API" ]] && die "HTTP API not found"
URL="https://${API}.execute-api.${AWS_REGION}.amazonaws.com"
ok "endpoint: $URL"
check "root returns HTTP 200" "200" "$(curl -s -o /dev/null -w '%{http_code}' -m 15 "$URL")"
BODY=$(curl -s -m 15 -XPOST "$URL/notes" -d '{"text":"verification run"}')
if echo "$BODY" | jq -e '.created' >/dev/null 2>&1; then
  ok "POST /notes wrote an item"; PASS=$((PASS+1))
else bad "POST /notes failed: $BODY"; FAIL=$((FAIL+1)); fi
COUNT=$(curl -s -m 15 "$URL/notes" | jq -r '.count // "err"')
if [[ "$COUNT" =~ ^[0-9]+$ ]] && (( COUNT > 0 )); then
  ok "GET /notes returned $COUNT item(s) via Query"; PASS=$((PASS+1))
else bad "GET /notes did not return items (got '$COUNT')"; FAIL=$((FAIL+1)); fi

hdr "What this stack deliberately does not have"
for probe in \
  "VPCs|$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'length(Vpcs)' --output text)" \
  "EC2 instances|$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$TAG_PROJECT" "Name=instance-state-name,Values=running" --query 'length(Reservations[].Instances[])' --output text)" \
  "NAT gateways|$(aws ec2 describe-nat-gateways --query 'length(NatGateways[?State!=`deleted`])' --output text)" \
  ; do
  check "${probe%%|*}: none" "0" "${probe#*|}"
done

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m — the doc and reality disagree.\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
