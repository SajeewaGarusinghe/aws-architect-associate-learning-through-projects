#!/usr/bin/env bash
# Read-only. Asserts the deployed reality matches what docs/architecture.html claims.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh
PASS=0; FAIL=0
check(){ if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1));
         else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi; }

hdr "Comparing the live account against the architecture document"
ZONE=$(aws route53 list-hosted-zones --query "HostedZones[?contains(Name,'saa-lab-08')].Id|[0]" --output text)
[[ -z "$ZONE" || "$ZONE" == "None" ]] && die "hosted zone not found — is the stack deployed?"
ZID=${ZONE##*/}

hdr "Failover routing"
RR=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZID" --query 'ResourceRecordSets[?Failover!=null]' --output json)
check "two failover records on one name" "2" "$(echo "$RR" | jq 'length')"
check "one PRIMARY" "1" "$(echo "$RR" | jq '[.[]|select(.Failover=="PRIMARY")]|length')"
check "one SECONDARY" "1" "$(echo "$RR" | jq '[.[]|select(.Failover=="SECONDARY")]|length')"
check "TTL is 60s — the floor on recovery time" "60" "$(echo "$RR" | jq -r '.[0].TTL')"
if echo "$RR" | jq -e '.[]|select(.Failover=="PRIMARY")|.HealthCheckId' >/dev/null 2>&1; then
  ok "PRIMARY carries the health check"; PASS=$((PASS+1))
else bad "PRIMARY has no health check — failover can never trigger"; FAIL=$((FAIL+1)); fi
if echo "$RR" | jq -e '.[]|select(.Failover=="SECONDARY")|.HealthCheckId' >/dev/null 2>&1; then
  warn "SECONDARY has a health check; nothing exists to fail over to beyond it"
else ok "SECONDARY has none, as expected"; PASS=$((PASS+1)); fi

hdr "Health check"
HC=$(aws route53 list-health-checks --query "HealthChecks[?HealthCheckConfig.FullyQualifiedDomainName=='example.com'].Id|[0]" --output text)
[[ -z "$HC" || "$HC" == "None" ]] && die "health check not found"
CFG=$(aws route53 get-health-check --health-check-id "$HC" --query HealthCheck.HealthCheckConfig --output json)
check "checks every 30s" "30" "$(echo "$CFG" | jq -r '.RequestInterval')"
check "fails after 2 consecutive failures" "2" "$(echo "$CFG" | jq -r '.FailureThreshold')"
STATUS=$(aws route53 get-health-check-status --health-check-id "$HC" \
  --query 'HealthCheckObservations[].StatusReport.Status' --output text 2>/dev/null | head -c 200)
ok "current observations: ${STATUS:0:120}"

hdr "Recovery point — decided in advance, not after"
BUCKET=$(aws s3api list-buckets --query "Buckets[?starts_with(Name,'saa-lab-08-data')].Name|[0]" --output text)
check "S3 versioning enabled" "Enabled" \
  "$(aws s3api get-bucket-versioning --bucket "$BUCKET" --query Status --output text)"
check "DynamoDB point-in-time recovery enabled" "ENABLED" \
  "$(aws dynamodb describe-continuous-backups --table-name saa-lab-08-orders \
     --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus' --output text 2>/dev/null)"

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
