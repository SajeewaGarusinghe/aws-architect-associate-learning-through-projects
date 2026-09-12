#!/usr/bin/env bash
# Read-only. Asserts the deployed reality matches what docs/architecture.html claims.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh
PASS=0; FAIL=0
check(){ if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1));
         else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi; }

hdr "Comparing the live account against the architecture document"
T=$(aws cloudtrail describe-trails --trail-name-list saa-lab-10-trail --query 'trailList[0]' --output json 2>/dev/null)
[[ -z "$T" || "$T" == "null" ]] && die "trail not found — is the stack deployed?"

hdr "CloudTrail"
check "multi-region — a single-region trail misses calls elsewhere" "true" "$(echo "$T" | jq -r '.IsMultiRegionTrail')"
check "global service events included" "true" "$(echo "$T" | jq -r '.IncludeGlobalServiceEvents')"
check "log file validation on — tampering is detectable" "true" "$(echo "$T" | jq -r '.LogFileValidationEnabled')"
check "actively logging" "True" \
  "$(aws cloudtrail get-trail-status --name saa-lab-10-trail --query IsLogging --output text)"
EVENTS=$(aws cloudtrail lookup-events --max-results 5 --query 'length(Events)' --output text 2>/dev/null)
[[ "$EVENTS" =~ ^[0-9]+$ ]] && (( EVENTS > 0 )) \
  && { ok "lookup-events returns history ($EVENTS of the last 5)"; PASS=$((PASS+1)); } \
  || { warn "no events returned yet — the trail may still be warming up"; }

hdr "AWS Config"
REC=$(aws configservice describe-configuration-recorders --query 'ConfigurationRecorders[0]' --output json 2>/dev/null)
check "recorder is scoped, not AllSupported" "false" "$(echo "$REC" | jq -r '.recordingGroup.allSupported')"
check "four resource types recorded" "4" "$(echo "$REC" | jq '.recordingGroup.resourceTypes|length')"
check "recorder running" "True" \
  "$(aws configservice describe-configuration-recorder-status --query 'ConfigurationRecordersStatus[0].recording' --output text 2>/dev/null)"
RULES=$(aws configservice describe-config-rules --query 'ConfigRules[?starts_with(ConfigRuleName,`saa-lab-10`)].ConfigRuleName' --output text)
check "two managed rules present" "2" "$(echo "$RULES" | wc -w)"
aws configservice describe-compliance-by-config-rule \
  --query 'ComplianceByConfigRules[].{rule:ConfigRuleName,state:Compliance.ComplianceType}' --output table 2>/dev/null | head -12

hdr "Budget"
BUDGET=$(aws budgets describe-budgets --account-id "$ACCOUNT_ID" \
  --query "Budgets[?BudgetName=='saa-lab-10-monthly']|[0]" --output json 2>/dev/null)
if [[ -n "$BUDGET" && "$BUDGET" != "null" ]]; then
  ok "budget exists, limit \$$(echo "$BUDGET" | jq -r '.BudgetLimit.Amount')"; PASS=$((PASS+1))
  NOTIF=$(aws budgets describe-notifications-for-budget --account-id "$ACCOUNT_ID" \
    --budget-name saa-lab-10-monthly --query 'Notifications[].NotificationType' --output text 2>/dev/null)
  grep -q FORECASTED <<<"$NOTIF" \
    && { ok "a FORECASTED alert exists — it warns before the money is spent"; PASS=$((PASS+1)); } \
    || { bad "no FORECASTED notification; ACTUAL alone only warns after the fact"; FAIL=$((FAIL+1)); }
else bad "budget not found"; FAIL=$((FAIL+1)); fi

hdr "The audit bucket is not public"
B=$(aws s3api list-buckets --query "Buckets[?starts_with(Name,'saa-lab-10-audit')].Name|[0]" --output text)
check "public access blocked" "true" \
  "$(aws s3api get-public-access-block --bucket "$B" --query 'PublicAccessBlockConfiguration.BlockPublicPolicy' --output text)"

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
