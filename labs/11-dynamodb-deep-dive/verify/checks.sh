#!/usr/bin/env bash
# Read-mostly. Asserts the deployed reality matches docs/architecture.html, then
# runs a live demo against the table: conditional writes, a transaction, a GSI
# query, an LSI query, and a round trip through DynamoDB Streams. Every write
# it makes is fractions of a cent on an on-demand table.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh

PASS=0; FAIL=0
check() {
  if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1))
  else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi
}
FN=saa-lab-11-stream-processor
TABLE=saa-lab-11-orders

hdr "Comparing the live account against the architecture document"

hdr "Table shape"
T=$(aws dynamodb describe-table --table-name "$TABLE" --query 'Table' --output json 2>/dev/null)
[[ -z "$T" || "$T" == "null" ]] && die "table $TABLE not found — is the stack deployed?"
check "table is active" "ACTIVE" "$(echo "$T" | jq -r '.TableStatus')"
check "billing is on-demand" "PAY_PER_REQUEST" "$(echo "$T" | jq -r '.BillingModeSummary.BillingMode')"
check "primary key: pk HASH + sk RANGE" "pk:HASH,sk:RANGE" \
  "$(echo "$T" | jq -r '[.KeySchema[] | "\(.AttributeName):\(.KeyType)"] | join(",")')"
check "one GSI: gsi1-status-by-time" "gsi1-status-by-time" \
  "$(echo "$T" | jq -r '.GlobalSecondaryIndexes[0].IndexName')"
check "one LSI: lsi1-by-total" "lsi1-by-total" \
  "$(echo "$T" | jq -r '.LocalSecondaryIndexes[0].IndexName')"
check "stream enabled, NEW_AND_OLD_IMAGES" "NEW_AND_OLD_IMAGES" \
  "$(echo "$T" | jq -r '.StreamSpecification.StreamViewType')"
STREAM_ARN=$(echo "$T" | jq -r '.LatestStreamArn')

hdr "TTL and backups"
check "TTL attribute is expiresAt, enabled" "expiresAt:ENABLED" \
  "$(aws dynamodb describe-time-to-live --table-name "$TABLE" \
     --query "join(':', [TimeToLiveDescription.AttributeName, TimeToLiveDescription.TimeToLiveStatus])" --output text)"
check "point-in-time recovery is enabled" "ENABLED" \
  "$(aws dynamodb describe-continuous-backups --table-name "$TABLE" \
     --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus' --output text)"

hdr "Stream consumer"
J=$(aws lambda get-function-configuration --function-name "$FN" --output json 2>/dev/null)
[[ -z "$J" || "$J" == "null" ]] && die "function $FN not found"
check "function is NOT attached to a VPC" "null" \
  "$(echo "$J" | jq -r '(.VpcConfig.VpcId // "") | if . == "" then "null" else . end')"
check "event source mapping is enabled" "Enabled" \
  "$(aws lambda list-event-source-mappings --function-name "$FN" \
     --query 'EventSourceMappings[0].State' --output text)"

hdr "Least privilege"
ROLE=$(echo "$J" | jq -r '.Role' | awk -F/ '{print $NF}')
POL=$(aws iam get-role-policy --role-name "$ROLE" --policy-name stream-read-and-audit-write \
  --query 'PolicyDocument' --output json 2>/dev/null)
check "table-write statement is scoped to one action" "1" \
  "$(echo "$POL" | jq '[.Statement[] | select(.Resource | test("/stream/") | not)][0].Action | if type=="array" then length else 1 end')"
if echo "$POL" | jq -r '[.Statement[].Action] | flatten | .[]' | grep -q '\*'; then
  bad "policy contains a wildcard action"; FAIL=$((FAIL+1))
else ok "no wildcard actions in the policy"; PASS=$((PASS+1)); fi

# ----------------------------------------------------------------- live demo
hdr "Live demo — products and an order"
aws dynamodb put-item --table-name "$TABLE" --item '{
  "pk": {"S": "PRODUCT#widget"}, "sk": {"S": "PRODUCT#widget"},
  "stock": {"N": "3"}, "version": {"N": "1"}
}' >/dev/null
ok "seeded PRODUCT#widget with stock=3, version=1"

hdr "Conditional write — succeeds while stock lasts"
if aws dynamodb update-item --table-name "$TABLE" \
  --key '{"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}}' \
  --update-expression 'SET stock = stock - :one, version = version + :one' \
  --condition-expression 'stock > :zero' \
  --expression-attribute-values '{":one":{"N":"1"},":zero":{"N":"0"}}' >/dev/null 2>&1; then
  ok "decremented stock 3 -> 2 (condition met)"; PASS=$((PASS+1))
else bad "conditional decrement unexpectedly failed"; FAIL=$((FAIL+1)); fi

hdr "Conditional write — fails once stock is exhausted"
aws dynamodb update-item --table-name "$TABLE" \
  --key '{"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}}' \
  --update-expression 'SET stock = :zero' \
  --expression-attribute-values '{":zero":{"N":"0"}}' >/dev/null
ERR=$(aws dynamodb update-item --table-name "$TABLE" \
  --key '{"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}}' \
  --update-expression 'SET stock = stock - :one' \
  --condition-expression 'stock > :zero' \
  --expression-attribute-values '{":one":{"N":"1"},":zero":{"N":"0"}}' 2>&1 >/dev/null || true)
if echo "$ERR" | grep -q 'ConditionalCheckFailedException'; then
  ok "out-of-stock decrement correctly rejected: ConditionalCheckFailedException"; PASS=$((PASS+1))
else bad "expected ConditionalCheckFailedException, got: $ERR"; FAIL=$((FAIL+1)); fi

hdr "Transaction — order + stock move together, or not at all"
aws dynamodb update-item --table-name "$TABLE" \
  --key '{"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}}' \
  --update-expression 'SET stock = :two' --expression-attribute-values '{":two":{"N":"2"}}' >/dev/null
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if aws dynamodb transact-write-items --transact-items '[
  {"Update": {"TableName":"'"$TABLE"'",
    "Key": {"pk":{"S":"PRODUCT#widget"},"sk":{"S":"PRODUCT#widget"}},
    "UpdateExpression": "SET stock = stock - :one",
    "ConditionExpression": "stock > :zero",
    "ExpressionAttributeValues": {":one":{"N":"1"},":zero":{"N":"0"}}}},
  {"Put": {"TableName":"'"$TABLE"'",
    "Item": {"pk":{"S":"CUSTOMER#demo"},"sk":{"S":"ORDER#1"},
      "status":{"S":"PENDING"},"createdAt":{"S":"'"$NOW"'"},"total":{"N":"42"}}}}
]' >/dev/null 2>&1; then
  ok "TransactWriteItems: stock decremented and order created atomically"; PASS=$((PASS+1))
else bad "transaction unexpectedly failed"; FAIL=$((FAIL+1)); fi

hdr "GSI query — orders by status, no Scan"
sleep 2
COUNT=$(aws dynamodb query --table-name "$TABLE" --index-name gsi1-status-by-time \
  --key-condition-expression '#s = :s' --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":s":{"S":"PENDING"}}' \
  --query 'Count' --output text)
if (( COUNT >= 1 )); then ok "gsi1-status-by-time returned $COUNT PENDING order(s)"; PASS=$((PASS+1))
else bad "GSI query returned no PENDING orders"; FAIL=$((FAIL+1)); fi

hdr "LSI query — one customer's orders sorted by total"
COUNT=$(aws dynamodb query --table-name "$TABLE" --index-name lsi1-by-total \
  --key-condition-expression 'pk = :p' --expression-attribute-values '{":p":{"S":"CUSTOMER#demo"}}' \
  --query 'Count' --output text)
if (( COUNT >= 1 )); then ok "lsi1-by-total returned $COUNT order(s) for CUSTOMER#demo"; PASS=$((PASS+1))
else bad "LSI query returned nothing"; FAIL=$((FAIL+1)); fi

hdr "Streams round trip — status change should reach the audit log"
aws dynamodb update-item --table-name "$TABLE" \
  --key '{"pk":{"S":"CUSTOMER#demo"},"sk":{"S":"ORDER#1"}}' \
  --update-expression 'SET #s = :shipped' --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":shipped":{"S":"SHIPPED"}}' >/dev/null
info "waiting up to 20s for the stream-triggered Lambda to write the audit item"
FOUND=0
for _ in $(seq 1 10); do
  N=$(aws dynamodb query --table-name "$TABLE" \
    --key-condition-expression 'pk = :a' \
    --filter-expression 'contains(detail, :d)' \
    --expression-attribute-values '{":a":{"S":"AUDIT"},":d":{"S":"PENDING -> SHIPPED"}}' \
    --query 'Count' --output text 2>/dev/null || echo 0)
  if [[ "$N" =~ ^[0-9]+$ ]] && (( N >= 1 )); then FOUND=1; break; fi
  sleep 2
done
if (( FOUND == 1 )); then ok "stream processor wrote an audit item for PENDING -> SHIPPED"; PASS=$((PASS+1))
else bad "no audit item appeared — check CloudWatch Logs for $FN"; FAIL=$((FAIL+1)); fi

hdr "What this stack deliberately does not have"
for probe in \
  "VPCs|$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$TAG_PROJECT" --query 'length(Vpcs)' --output text)" \
  "EC2 instances|$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$TAG_PROJECT" "Name=instance-state-name,Values=running" --query 'length(Reservations[].Instances[])' --output text)" \
  ; do
  check "${probe%%|*}: none" "0" "${probe#*|}"
done

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m — the doc and reality disagree.\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
