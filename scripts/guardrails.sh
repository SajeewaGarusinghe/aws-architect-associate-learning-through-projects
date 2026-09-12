#!/usr/bin/env bash
# Shared safety rails. Sourced by every other script in this repo.

export AWS_REGION="${AWS_REGION:-ap-southeast-2}"
export AWS_DEFAULT_REGION="$AWS_REGION"

ACCOUNT_ID="213104855858"

# Resources that exist outside the labs. Nothing here may ever be modified or deleted.
# i-02060040f8335f406 is the EC2 host running the Claude Code session itself; destroying
# it would kill both the working environment and the operator's access to the account.
PROTECTED_INSTANCES=("i-02060040f8335f406")
PROTECTED_VPCS=("vpc-0f4d9a74d92ad4dfc" "vpc-0ac6952c1ea149bbb")
PROTECTED_KEYPAIRS=("amaradhasa_key")

TAG_PROJECT="saa-labs"
BASELINE_INSTANCE_COUNT=1
BASELINE_VPC_COUNT=2

die()  { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[1;31m✗\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*"; }
hdr()  { printf '\n\033[1;37m%s\033[0m\n' "$*"; printf '%*s\n' "${#1}" '' | tr ' ' '-'; }

is_protected() {
  local id="$1" p
  for p in "${PROTECTED_INSTANCES[@]}" "${PROTECTED_VPCS[@]}" "${PROTECTED_KEYPAIRS[@]}"; do
    [[ "$id" == "$p" ]] && return 0
  done
  return 1
}

assert_not_protected() {
  local id
  for id in "$@"; do
    if is_protected "$id"; then
      die "refusing to act on protected resource: $id"
    fi
  done
}

# Lab stacks are named saa-lab-NN-slug. Teardown refuses anything that is not one,
# so a mistyped or unrelated stack name can never be deleted by these scripts.
assert_lab_stack() {
  [[ "$1" =~ ^saa-lab-[0-9]{2}-[a-z0-9-]+$ ]] \
    || die "'$1' is not a lab stack name (expected saa-lab-NN-slug)"
}

stack_name_for() { echo "saa-lab-$(basename "${1%/}")"; }

verify_account() {
  local actual
  actual="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" \
    || die "cannot reach AWS — check credentials"
  [[ "$actual" == "$ACCOUNT_ID" ]] || die "wrong AWS account: expected $ACCOUNT_ID, got $actual"
}

stack_status() {
  aws cloudformation describe-stacks --stack-name "$1" \
    --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "DOES_NOT_EXIST"
}
