#!/usr/bin/env bash
# Deploy a lab stack. Previews by default; only --yes actually creates resources.
#   ./scripts/deploy.sh labs/01-vpc-from-scratch          # preview, costs nothing
#   ./scripts/deploy.sh labs/01-vpc-from-scratch --yes    # create, starts the meter
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/guardrails.sh

LAB="${1:?usage: deploy.sh LAB_DIR [--yes]}"; LAB="${LAB%/}"
EXECUTE=false; [[ "${2:-}" == "--yes" ]] && EXECUTE=true

TEMPLATE="$LAB/infra/template.yaml"
[[ -f "$TEMPLATE" ]] || die "no template at $TEMPLATE"
STACK="$(stack_name_for "$LAB")"
assert_lab_stack "$STACK"
verify_account

hdr "Validating $TEMPLATE"
aws cloudformation validate-template --template-body "file://$TEMPLATE" \
  --query 'Description' --output text
ok "template is syntactically valid (validation is free)"

STATUS="$(stack_status "$STACK")"
if [[ "$STATUS" == "REVIEW_IN_PROGRESS" ]]; then
  info "clearing previous preview-only stack"
  aws cloudformation delete-stack --stack-name "$STACK"
  aws cloudformation wait stack-delete-complete --stack-name "$STACK" 2>/dev/null || true
  STATUS="DOES_NOT_EXIST"
fi

CS_TYPE=UPDATE; [[ "$STATUS" == "DOES_NOT_EXIST" ]] && CS_TYPE=CREATE
CS="deploy-$(date -u +%Y%m%d-%H%M%S)"

# Labs needing values that must not be committed (an alert email, say) keep them
# in infra/params.json, which is gitignored. See the lab's README.
PARAMS=()
if [[ -f "$LAB/infra/params.json" ]]; then
  PARAMS=(--parameters "file://$LAB/infra/params.json")
  info "using parameters from $LAB/infra/params.json"
fi

hdr "Change set ($CS_TYPE) for $STACK"
aws cloudformation create-change-set \
  --stack-name "$STACK" --change-set-name "$CS" --change-set-type "$CS_TYPE" \
  --template-body "file://$TEMPLATE" \
  "${PARAMS[@]}" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --tags "Key=Project,Value=$TAG_PROJECT" \
         "Key=Lab,Value=$(basename "$LAB")" \
         "Key=ManagedBy,Value=cloudformation" >/dev/null

aws cloudformation wait change-set-create-complete \
  --stack-name "$STACK" --change-set-name "$CS" 2>/dev/null \
  || die "change set failed: $(aws cloudformation describe-change-set --stack-name "$STACK" --change-set-name "$CS" --query StatusReason --output text)"

aws cloudformation describe-change-set --stack-name "$STACK" --change-set-name "$CS" \
  --query 'Changes[].ResourceChange.{Action:Action,Type:ResourceType,Resource:LogicalResourceId}' \
  --output table
COUNT=$(aws cloudformation describe-change-set --stack-name "$STACK" --change-set-name "$CS" \
  --query 'length(Changes)' --output text)

if ! $EXECUTE; then
  printf '\n\033[1;33mPREVIEW ONLY\033[0m — %s resources planned. Nothing has been created.\n' "$COUNT"
  echo "The stack sits in REVIEW_IN_PROGRESS holding no resources, which costs nothing."
  echo "To build it for real:  ./scripts/deploy.sh $LAB --yes"
  exit 0
fi

hdr "Deploying $COUNT resources — the meter starts now"
aws cloudformation execute-change-set --stack-name "$STACK" --change-set-name "$CS"
START=$(date -u +%s)
aws cloudformation wait "stack-${CS_TYPE,,}-complete" --stack-name "$STACK" \
  || die "deploy failed — see: aws cloudformation describe-stack-events --stack-name $STACK"

printf 'START=%s\nSTACK=%s\n' "$START" "$STACK" > "$LAB/.live-state"
aws cloudformation list-stack-resources --stack-name "$STACK" \
  --query 'StackResourceSummaries[].[ResourceType,PhysicalResourceId,LogicalResourceId]' --output text \
  > "$LAB/.live-resources"

ok "stack $STACK is live as of $(date -u -d "@$START" +%H:%M:%SZ)"
hdr "Stack outputs"
aws cloudformation describe-stacks --stack-name "$STACK" \
  --query 'Stacks[0].Outputs[].{Key:OutputKey,Value:OutputValue}' --output table
printf '\n\033[1;33mThe meter is running.\033[0m Tear down with: ./scripts/teardown.sh %s --yes\n' "$LAB"
