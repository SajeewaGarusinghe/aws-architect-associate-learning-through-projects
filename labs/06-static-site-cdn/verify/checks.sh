#!/usr/bin/env bash
# Read-only. Asserts the deployed reality matches what docs/architecture.html claims.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh
PASS=0; FAIL=0
check(){ if [[ "$2" == "$3" ]]; then ok "$1"; PASS=$((PASS+1));
         else bad "$1 — doc says '$2', account says '$3'"; FAIL=$((FAIL+1)); fi; }

hdr "Comparing the live account against the architecture document"
BUCKET=$(aws s3api list-buckets --query "Buckets[?starts_with(Name,'saa-lab-06-site')].Name|[0]" --output text)
[[ -z "$BUCKET" || "$BUCKET" == "None" ]] && die "site bucket not found — is the stack deployed?"

hdr "The bucket is genuinely private"
PAB=$(aws s3api get-public-access-block --bucket "$BUCKET" --query PublicAccessBlockConfiguration --output json)
for k in BlockPublicAcls BlockPublicPolicy IgnorePublicAcls RestrictPublicBuckets; do
  check "$k is on" "true" "$(echo "$PAB" | jq -r ".$k")"
done
check "versioning enabled" "Enabled" \
  "$(aws s3api get-bucket-versioning --bucket "$BUCKET" --query Status --output text)"
check "default encryption set" "AES256" \
  "$(aws s3api get-bucket-encryption --bucket "$BUCKET" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text 2>/dev/null)"

hdr "Only CloudFront may read it"
POL=$(aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text 2>/dev/null)
check "policy principal is the CloudFront service" "cloudfront.amazonaws.com" \
  "$(echo "$POL" | jq -r '.Statement[0].Principal.Service')"
if echo "$POL" | jq -e '.Statement[0].Condition.StringEquals["AWS:SourceArn"]' >/dev/null 2>&1; then
  ok "policy is scoped to one distribution ARN"; PASS=$((PASS+1))
else bad "policy has no source-ARN condition — any distribution could use this bucket"; FAIL=$((FAIL+1)); fi

hdr "Distribution"
DIST=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[0].DomainName=='${BUCKET}.s3.${AWS_REGION}.amazonaws.com'].Id|[0]" --output text 2>/dev/null)
[[ -z "$DIST" || "$DIST" == "None" ]] && DIST=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment,'saa-lab-06')].Id|[0]" --output text)
[[ -z "$DIST" || "$DIST" == "None" ]] && die "distribution not found"
D=$(aws cloudfront get-distribution --id "$DIST" --query Distribution --output json)
check "distribution deployed" "Deployed" "$(echo "$D" | jq -r '.Status')"
check "HTTP redirects to HTTPS" "redirect-to-https" \
  "$(echo "$D" | jq -r '.DistributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy')"
check "origin access control attached" "true" \
  "$(echo "$D" | jq -r '(.DistributionConfig.Origins.Items[0].OriginAccessControlId != "")')"
check "a second cache behaviour exists" "1" \
  "$(echo "$D" | jq -r '.DistributionConfig.CacheBehaviors.Quantity')"
check "403 mapped to a custom error page" "403" \
  "$(echo "$D" | jq -r '.DistributionConfig.CustomErrorResponses.Items[0].ErrorCode')"

DOMAIN=$(echo "$D" | jq -r '.DomainName')
hdr "Behaviour over the wire"
ok "site: https://$DOMAIN"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "https://$DOMAIN/")
if [[ "$CODE" == "200" ]]; then ok "site returns 200"; PASS=$((PASS+1))
elif [[ "$CODE" == "404" || "$CODE" == "403" ]]; then
  warn "site returns $CODE — has index.html been uploaded yet?"
else bad "site returned $CODE"; FAIL=$((FAIL+1)); fi
DIRECT=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "https://${BUCKET}.s3.${AWS_REGION}.amazonaws.com/index.html")
if [[ "$DIRECT" == "403" ]]; then ok "direct S3 URL returns 403 — the bucket really is private"; PASS=$((PASS+1))
else bad "direct S3 URL returned $DIRECT, expected 403"; FAIL=$((FAIL+1)); fi

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
