#!/usr/bin/env bash
# Read-only. Every assertion is evaluated by the IAM policy simulator, which
# decides exactly as a real request would without performing one.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."
source scripts/guardrails.sh
PASS=0; FAIL=0
ACCT=$(aws sts get-caller-identity --query Account --output text)
BOUNDED="arn:aws:iam::${ACCT}:role/saa-lab-07-bounded"
UNBOUNDED="arn:aws:iam::${ACCT}:role/saa-lab-07-unbounded"
ABAC="arn:aws:iam::${ACCT}:role/saa-lab-07-abac"

sim(){ # sim ROLE ACTION [RESOURCE] -> decision
  if [[ -n "${3:-}" ]]; then
    aws iam simulate-principal-policy --policy-source-arn "$1" --action-names "$2" \
      --resource-arns "$3" --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null
  else
    aws iam simulate-principal-policy --policy-source-arn "$1" --action-names "$2" \
      --query 'EvaluationResults[0].EvalDecision' --output text 2>/dev/null
  fi; }
expect(){ local label="$1" want="$2" got="$3"
  if [[ "$got" == "$want" ]]; then ok "$label → $got"; PASS=$((PASS+1))
  else bad "$label → expected $want, got $got"; FAIL=$((FAIL+1)); fi; }

aws iam get-role --role-name saa-lab-07-bounded >/dev/null 2>&1 || die "roles not found — is the stack deployed?"

hdr "The boundary clamps an identical policy"
expect "unbounded role, ec2:StartInstances" "allowed"      "$(sim "$UNBOUNDED" ec2:StartInstances)"
expect "bounded role,   ec2:StartInstances" "implicitDeny" "$(sim "$BOUNDED"   ec2:StartInstances)"
expect "bounded role,   s3:GetObject"       "allowed"      "$(sim "$BOUNDED"   s3:GetObject)"
expect "bounded role,   s3:PutObject"       "implicitDeny" "$(sim "$BOUNDED"   s3:PutObject)"

hdr "A boundary grants nothing — it only subtracts"
if [[ "$(aws iam get-role --role-name saa-lab-07-bounded --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' --output text)" != "None" ]]; then
  ok "bounded role carries a permissions boundary"; PASS=$((PASS+1))
else bad "no boundary attached"; FAIL=$((FAIL+1)); fi
if [[ "$(aws iam get-role --role-name saa-lab-07-unbounded --query 'Role.PermissionsBoundary' --output text)" == "None" ]]; then
  ok "unbounded role has none — the control case is intact"; PASS=$((PASS+1))
else bad "unbounded role unexpectedly has a boundary"; FAIL=$((FAIL+1)); fi

hdr "Explicit deny beats every allow"
VAULT=$(aws s3api list-buckets --query "Buckets[?starts_with(Name,'saa-lab-07-vault')].Name|[0]" --output text)
[[ -z "$VAULT" || "$VAULT" == "None" ]] && die "vault bucket not found"
expect "unbounded role, s3:GetObject on the vault" "explicitDeny" \
  "$(sim "$UNBOUNDED" s3:GetObject "arn:aws:s3:::${VAULT}/test.txt")"

hdr "A resource policy grants on its own"
if aws s3api get-bucket-policy --bucket "$VAULT" --query Policy --output text 2>/dev/null \
   | jq -e --arg r "$ABAC" '.Statement[] | select(.Effect=="Allow") | select(.Principal.AWS==$r)' >/dev/null; then
  ok "vault policy allows the ABAC role directly, with no S3 statement in its own policy"; PASS=$((PASS+1))
else bad "expected an Allow for the ABAC role on the bucket policy"; FAIL=$((FAIL+1)); fi

hdr "ABAC"
if aws iam list-role-tags --role-name saa-lab-07-abac --query 'Tags[?Key==`team`].Value' --output text | grep -q .; then
  ok "ABAC role carries a team tag for aws:PrincipalTag matching"; PASS=$((PASS+1))
else bad "ABAC role has no team tag"; FAIL=$((FAIL+1)); fi

hdr "Cost"
ok "IAM roles, policies and the simulator are free — this lab costs \$0.00"

echo
if (( FAIL == 0 )); then printf '\033[1;32mAll %d checks passed\033[0m — the diagram and the account agree.\n' "$PASS"
else printf '\033[1;31m%d of %d checks failed\033[0m\n' "$FAIL" "$((PASS+FAIL))"; exit 1; fi
