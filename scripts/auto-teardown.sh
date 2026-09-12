#!/usr/bin/env bash
# Safety net: destroy a lab stack after a delay unless cancelled first.
# Detached from the session on purpose, so the stack still comes down if the
# terminal, the agent, or the machine's session goes away.
#
#   ./scripts/auto-teardown.sh labs/01-vpc-from-scratch 1800   # arm for 30 min
#   ./scripts/auto-teardown.sh --cancel labs/01-vpc-from-scratch
#   ./scripts/auto-teardown.sh --status labs/01-vpc-from-scratch
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

MODE=arm
case "${1:-}" in
  --cancel) MODE=cancel; shift ;;
  --status) MODE=status; shift ;;
esac

LAB="${1:?usage: auto-teardown.sh [--cancel|--status] LAB_DIR [DELAY_SECONDS]}"; LAB="${LAB%/}"
DELAY="${2:-1800}"
PIDF="$LAB/.auto-teardown.pid"
CANCEL="$LAB/.auto-teardown.cancel"
LOG="$LAB/.auto-teardown.log"

case "$MODE" in
  cancel)
    touch "$CANCEL"
    if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
      kill "$(cat "$PIDF")" 2>/dev/null || true
      echo "Auto-teardown CANCELLED. The stack will stay up until you tear it down by hand:"
    else
      echo "No armed timer was running. Cancel flag set anyway."
    fi
    rm -f "$PIDF"
    echo "  ./scripts/teardown.sh $LAB --yes"
    exit 0 ;;
  status)
    if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
      DEADLINE=$(cat "$LAB/.auto-teardown.deadline" 2>/dev/null || echo 0)
      LEFT=$(( DEADLINE - $(date -u +%s) ))
      printf 'ARMED — teardown in %d min %d sec (at %s)\n' \
        $(( LEFT / 60 )) $(( LEFT % 60 )) "$(date -u -d "@$DEADLINE" '+%H:%M:%SZ')"
    else
      echo "not armed"
    fi
    exit 0 ;;
esac

# --- arm -------------------------------------------------------------------
rm -f "$CANCEL"
DEADLINE=$(( $(date -u +%s) + DELAY ))
echo "$DEADLINE" > "$LAB/.auto-teardown.deadline"
echo $$ > "$PIDF"

{
  echo "armed $(date -u '+%Y-%m-%d %H:%M:%SZ') — teardown at $(date -u -d "@$DEADLINE" '+%H:%M:%SZ')"
} >> "$LOG"

# Wake every 15s so a cancel takes effect promptly.
while [[ $(date -u +%s) -lt $DEADLINE ]]; do
  if [[ -f "$CANCEL" ]]; then
    echo "cancelled $(date -u '+%H:%M:%SZ') — stack left running" >> "$LOG"
    rm -f "$PIDF"; exit 0
  fi
  sleep 15
done

[[ -f "$CANCEL" ]] && { rm -f "$PIDF"; exit 0; }

echo "deadline reached $(date -u '+%H:%M:%SZ') — tearing down" >> "$LOG"
./scripts/teardown.sh "$LAB" --yes >> "$LOG" 2>&1
echo "teardown finished rc=$? $(date -u '+%H:%M:%SZ')" >> "$LOG"
rm -f "$PIDF"
