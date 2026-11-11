#!/bin/bash
# The one Stop hook VS Code runs. It passes the same input to each check in priority order and
# returns the first block: unverified code edits, then an ending that hands the user a question
# they shouldn't have to answer. Each check is its own script with its own loop guard, so it can be
# tested alone. Every block is logged, so false positives can be found later.

set -uo pipefail
export LC_ALL=en_US.UTF-8

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOG_DIR=${COPILOT_HOOK_LOG_DIR:-"$HOME/.local/state/copilot-hooks"}
INPUT=$(cat)

for check in verify-edits.sh stop-keep-going.sh; do
  OUT=$("$DIR/$check" <<<"$INPUT" 2>/dev/null) || continue
  [[ -n "$OUT" ]] || continue
  jq -e '.hookSpecificOutput.decision == "block"' <<<"$OUT" >/dev/null 2>&1 || continue
  printf '%s\n' "$OUT"
  if mkdir -p "$LOG_DIR" 2>/dev/null; then
    LOG="$LOG_DIR/stop.log"
    [[ -f "$LOG" ]] && (( $(wc -c <"$LOG" 2>/dev/null || echo 0) > 1000000 )) && mv "$LOG" "$LOG.1"
    REASON=$(jq -r '.hookSpecificOutput.reason' <<<"$OUT" | cut -c1-120)
    SESSION=$(jq -r '.session_id // "?"' <<<"$INPUT" 2>/dev/null)
    printf '%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$SESSION" "${check%.sh}" "$REASON" >>"$LOG"
  fi
  exit 0
done
exit 0
