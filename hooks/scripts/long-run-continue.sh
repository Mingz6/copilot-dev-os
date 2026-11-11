#!/bin/bash
# Stop hook scoped to the Zero-Interrupt Orchestrator (declared in its frontmatter).
# Keeps a /long-run going while the spec it is editing still says in-progress and the spec
# changed since the last push. When it runs as a subagent VS Code sends SubagentStop instead,
# and (unlike the docs) reads the decision from hookSpecificOutput there too.

set -uo pipefail
export LC_ALL=en_US.UTF-8

MAX_PUSHES=12
INPUT=$(cat)
EVENT=$(jq -r '.hook_event_name // "Stop"' <<<"$INPUT" 2>/dev/null)
SESSION=$(jq -r '[.session_id // "unknown", .agent_id // empty] | join("-")' <<<"$INPUT" 2>/dev/null)
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT" 2>/dev/null)
[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || exit 0

# Only specs this run wrote to, not ones it merely read for reference.
SPEC=$(jq -r 'select(.type == "tool.execution_start")
  | select(.data.toolName | test("^(create_file|replace_string_in_file|multi_replace_string_in_file)$"))
  | .data.arguments | (.filePath // empty), (.replacements[]?.filePath // empty)' "$TRANSCRIPT" 2>/dev/null \
  | grep -E '/specs/[^/]+\.md$' | tail -n 1)
[[ -n "$SPEC" && -f "$SPEC" ]] || exit 0
grep -qiE '^\*\*Status:\*\*[[:space:]]*in-progress' "$SPEC" || exit 0

OPEN=$(grep -cE '^[[:space:]]*- \[ \]' "$SPEC")
FINGERPRINT="$OPEN:$(date -r "$SPEC" +%s)"
STATE_DIR="${TMPDIR:-/tmp}/copilot-long-run"
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/${SESSION//[^A-Za-z0-9_-]/_}"
PUSHES=0 LAST=""
[[ -f "$STATE" ]] && read -r PUSHES LAST <"$STATE"

# Spec untouched since the last push: the run is stuck, so let it stop instead of burning credits.
[[ "$FINGERPRINT" == "$LAST" ]] && exit 0
(( PUSHES >= MAX_PUSHES )) && exit 0
echo "$((PUSHES + 1)) $FINGERPRINT" >"$STATE"

REASON="Long-run spec $SPEC still says **Status:** in-progress with $OPEN unchecked items. Keep going with the next unchecked item. When every evaluator passes, set **Status:** completed. For a hard stop, set **Status:** blocked and write the reason in the Progress Log."
jq -n --arg r "$REASON" --arg e "$EVENT" \
  '{decision: "block", reason: $r, hookSpecificOutput: {hookEventName: $e, decision: "block", reason: $r}}'
exit 0
