#!/bin/bash
# Stop check: this turn edited code or config and ran nothing that checks it after the last edit.
# Sends the agent back to build, test or lint once per round of edits, up to MAX_ROUNDS a turn, so
# a fix made after the first check gets checked too. Stopping again with no new edit passes.
# Docs (.md, .txt) don't count, and only tool calls after the latest user message are looked at.

set -uo pipefail
export LC_ALL=en_US.UTF-8
MAX_ROUNDS=5

INPUT=$(cat)
SESSION=$(jq -r '.session_id // "unknown"' <<<"$INPUT" 2>/dev/null)
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT" 2>/dev/null)
[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || exit 0

LAST_USER=$(grep -nE '"type"[[:space:]]*:[[:space:]]*"user\.message"' "$TRANSCRIPT" | tail -n 1 | cut -d: -f1)
[[ -n "$LAST_USER" ]] || exit 0

CODE_RE='\.(py|pyi|ts|tsx|js|jsx|mjs|cjs|cs|csproj|props|targets|sh|bash|zsh|ps1|psm1|sql|bicep|json|jsonc|ya?ml|toml|swift|go|rs|java|kt|rb|php|css|scss|html|astro|vue|svelte|plist|xml|tf|ipynb)$'
VERIFY_RE='(^|[;&|[:space:](/])(pytest|py_compile|unittest|jest|vitest|mocha|tsc|eslint|ruff|pyright|mypy|shellcheck|bats|dotnet|npm|npx|pnpm|yarn|nx|cargo|go|gradle|mvn|make|pwsh|swift|swiftc|xcodebuild|plutil|docker|curl|node|deno|bun|astro|func)([[:space:]]|$)|python3?([[:space:]]|$)|bash[[:space:]]+-n|zsh[[:space:]]+-n|jq[[:space:]]|(^|[;&|][[:space:]]*)[^[:space:];&|]*\.(py|sh)([[:space:]]|$)|gh[[:space:]]+(pr[[:space:]]+checks|run[[:space:]]+(watch|view))'

# One line per tool call this turn: "E <path>" for an edit, "V" for anything that checks code.
EVENTS=$(tail -n +"$LAST_USER" "$TRANSCRIPT" | jq -r --arg verify "$VERIFY_RE" '
  select(.type == "tool.execution_start") | .data as $d | ($d.toolName // "") as $t |
  if ($t | test("^(create_file|replace_string_in_file|multi_replace_string_in_file|edit_notebook_file)$")) then
    ($d.arguments | (.filePath // empty), (.replacements[]?.filePath // empty)) | "E " + .
  elif ($t | test("^(get_errors|runTests|run_notebook_cell|mcp_pylance_mcp_s_pylance(SyntaxErrors|FileSyntaxErrors|Analyze|RunCodeSnippet))$")) then
    "V"
  elif $t == "run_in_terminal" and (($d.arguments.command // "") | test($verify; "i")) then
    "V"
  else empty end' 2>/dev/null)
[[ -n "$EVENTS" ]] || exit 0

LAST_EDIT=$(grep -nE "^E .*$CODE_RE" <<<"$EVENTS" | tail -n 1 | cut -d: -f1)
[[ -n "$LAST_EDIT" ]] || exit 0
tail -n +"$((LAST_EDIT + 1))" <<<"$EVENTS" | grep -qx 'V' && exit 0

STATE_DIR="${TMPDIR:-/tmp}/copilot-verify-edits"
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/${SESSION//[^A-Za-z0-9_-]/_}-turn$LAST_USER"
# State is "<blocks> <event line of the last edit at that block>"; an empty file is the old once-per-turn format.
BLOCKS=0 BLOCKED_AT=0
if [[ -s "$STATE" ]]; then
  read -r BLOCKS BLOCKED_AT <"$STATE"
elif [[ -f "$STATE" ]]; then
  BLOCKS=1 BLOCKED_AT=$LAST_EDIT
  printf '%s %s\n' "$BLOCKS" "$BLOCKED_AT" >"$STATE"
fi
[[ $BLOCKS =~ ^[0-9]+$ && $BLOCKED_AT =~ ^[0-9]+$ ]] || { BLOCKS=0; BLOCKED_AT=0; }
(( LAST_EDIT > BLOCKED_AT && BLOCKS < MAX_ROUNDS )) || exit 0
BLOCKS=$((BLOCKS + 1))
printf '%s %s\n' "$BLOCKS" "$LAST_EDIT" >"$STATE"

FILES=$(grep -E "^E .*$CODE_RE" <<<"$EVENTS" | cut -c3- | sort -u)
COUNT=$(grep -c . <<<"$FILES")
NAMES=$(xargs -n1 basename <<<"$FILES" 2>/dev/null | head -n 3 | paste -sd, - | sed 's/,/, /g')
REASON="Verify round $BLOCKS of $MAX_ROUNDS: you edited $COUNT code or config file(s) this turn ($NAMES) and ran nothing that checks them after the last edit. Run the build, the tests or at least a syntax check now, and fix what it finds. If nothing can run here, say why in one line."
jq -n --arg r "$REASON" '{hookSpecificOutput: {hookEventName: "Stop", decision: "block", reason: $r}}'
exit 0
