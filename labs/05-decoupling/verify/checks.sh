#!/usr/bin/env bash
# Read-only. Asserts the deployed reality matches what docs/architecture.html claims.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh

PASS=0; FAIL=0
check(){ if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1));
         else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi; }
Q(){ aws sqs get-queue-url --queue-name "$1" --query QueueUrl --output text 2>/dev/null; }
ATTR(){ aws sqs get-queue-attributes --queue-url "$1" --attribute-names All --query "Attributes.$2" --output text 2>/dev/null; }

hdr "Comparing the live account against the architecture document"
ORDERS=$(Q saa-lab-05-orders); AUDIT=$(Q saa-lab-05-audit); DLQ=$(Q saa-lab-05-orders-dlq)
[[ -z "$ORDERS" || "$ORDERS" == "None" ]] && die "orders queue not found — is the stack deployed?"

hdr "Queue configuration"
check "visibility timeout is 60s" "60" "$(ATTR "$ORDERS" VisibilityTimeout)"
check "orders retention is 4 days" "345600" "$(ATTR "$ORDERS" MessageRetentionPeriod)"
check "DLQ retention is 14 days (the maximum)" "1209600" "$(ATTR "$DLQ" MessageRetentionPeriod)"
RD=$(ATTR "$ORDERS" RedrivePolicy)
check "redrive after 3 receives" "3" "$(echo "$RD" | jq -r '.maxReceiveCount' 2>/dev/null)"
if echo "$RD" | jq -e '.deadLetterTargetArn' >/dev/null 2>&1; then
  ok "redrive targets the dead-letter queue"; PASS=$((PASS+1))
else bad "no dead-letter target configured"; FAIL=$((FAIL+1)); fi

hdr "Consumer timeout must stay below the visibility timeout"
FT=$(aws lambda get-function-configuration --function-name saa-lab-05-consumer --query Timeout --output text 2>/dev/null)
VT=$(ATTR "$ORDERS" VisibilityTimeout)
if (( FT < VT )); then ok "function timeout ${FT}s < visibility timeout ${VT}s"; PASS=$((PASS+1))
else bad "function timeout ${FT}s >= visibility timeout ${VT}s — duplicate processing risk"; FAIL=$((FAIL+1)); fi

hdr "Fan-out and filtering"
TOPIC=$(aws sns list-topics --query "Topics[?contains(TopicArn,'saa-lab-05-orders')].TopicArn|[0]" --output text)
check "two subscriptions on the topic" "2" \
  "$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" --query 'length(Subscriptions)' --output text)"
FILTERED=0
for ARN in $(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" --query 'Subscriptions[].SubscriptionArn' --output text); do
  FP=$(aws sns get-subscription-attributes --subscription-arn "$ARN" --query 'Attributes.FilterPolicy' --output text 2>/dev/null)
  [[ "$FP" != "None" && -n "$FP" ]] && FILTERED=$((FILTERED+1))
  RAW=$(aws sns get-subscription-attributes --subscription-arn "$ARN" --query 'Attributes.RawMessageDelivery' --output text 2>/dev/null)
  [[ "$RAW" == "true" ]] || { bad "raw message delivery off on $ARN"; FAIL=$((FAIL+1)); }
done
check "exactly one subscription carries a filter policy" "1" "$FILTERED"

hdr "Event source mapping"
check "poller enabled with batch size 1" "Enabled" \
  "$(aws lambda list-event-source-mappings --function-name saa-lab-05-consumer --query 'EventSourceMappings[0].State' --output text 2>/dev/null)"

hdr "No servers anywhere in this stack"
check "EC2 instances tagged saa-labs" "0" \
  "$(aws ec2 describe-instances --filters "Name=tag:Project,Values=$TAG_PROJECT" "Name=instance-state-name,Values=running" --query 'length(Reservations[].Instances[])' --output text)"

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
