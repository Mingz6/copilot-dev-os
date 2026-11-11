#!/bin/bash
# Runs one of the Copilot hook scripts under Claude Code. Both apps send and read the same
# PreToolUse/PostToolUse JSON; only the tool names and a few input keys differ. This renames
# Claude's (Bash, Edit, Write, mcp__server__tool, file_path) to the VS Code ones the scripts
# match on (run_in_terminal, replace_string_in_file, create_file, mcp_server_tool, filePath),
# then passes the script's stdout and exit code through unchanged.
# Stop is the exception: the Stop checks read Copilot's transcript (user.message, assistant.message,
# tool.execution_start), so this rewrites Claude's transcript into that shape in a temp file, runs
# stop.sh on it, and turns its hookSpecificOutput block into Claude's {decision, reason}.
# Usage (from ~/.claude/settings.json): claude-adapter.sh post-edit-lint.sh

set -uo pipefail
TARGET="$(cd "$(dirname "$0")" && pwd)/${1:?usage: claude-adapter.sh <hook-script>}"
[[ -x "$TARGET" ]] || { echo "claude-adapter: no hook script $TARGET" >&2; exit 1; }

INPUT=$(cat)

# Claude's tool name and input keys -> the VS Code ones. Shared by the tool hooks and the transcript rewrite.
JQ_DEFS='
  def tname($t): {Bash: "run_in_terminal", Write: "create_file", Edit: "replace_string_in_file",
      MultiEdit: "multi_replace_string_in_file", NotebookEdit: "edit_notebook_file"}[$t]
    // (if ($t | startswith("mcp__")) then ($t | sub("^mcp__"; "mcp_") | sub("__"; "_")) else $t end);
  def targs:
    if type == "object" then
      (.file_path // .notebook_path) as $fp
      | (if $fp then .filePath = $fp else . end)
      | (if has("old_string") then .oldString = .old_string else . end)
      | (if has("new_string") then .newString = .new_string else . end)
      | (if (.edits | type) == "array"
           then .replacements = [.edits[] | {filePath: $fp, oldString: .old_string, newString: .new_string}]
           else . end)
    else . end;
'

if [[ "$(jq -r '.hook_event_name // empty' <<<"$INPUT" 2>/dev/null)" == "Stop" ]]; then
  SRC=$(jq -r '.transcript_path // empty' <<<"$INPUT")
  TMP=$(mktemp "${TMPDIR:-/tmp}/claude-stop.XXXXXX") || exit 0
  trap 'rm -f "$TMP"' EXIT
  if [[ -n "$SRC" && -f "$SRC" ]]; then
    # Main-thread rows only. A user row with text is a prompt (tool results are user rows without text).
    jq -c "$JQ_DEFS"'
      select((.isSidechain // false) | not)
      | if .type == "user" and ((.isMeta // false) | not) then
          (.message.content | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("\n")) end) as $t
          | select($t != "" and ($t | startswith("<system-reminder>") | not))
          | {type: "user.message", data: {content: $t}}
        elif .type == "assistant" then
          (.message.content | if type == "array" then .[] else empty end)
          | if .type == "text" then {type: "assistant.message", data: {content: .text}}
            elif .type == "tool_use" then {type: "tool.execution_start", data: {toolName: tname(.name), toolCallId: .id, arguments: (.input | targs)}}
            else empty end
        else empty end' "$SRC" >"$TMP" 2>/dev/null
  fi
  MAPPED=$(jq -c --arg t "$TMP" '.transcript_path = $t' <<<"$INPUT")
  OUT=$("$TARGET" <<<"$MAPPED" 2>/dev/null)
  rc=$?
  if [[ -n "$OUT" ]]; then
    jq -c 'if .hookSpecificOutput.decision == "block" then {decision: "block", reason: .hookSpecificOutput.reason} else . end' <<<"$OUT" 2>/dev/null || printf '%s\n' "$OUT"
  fi
  exit $rc
fi

MAPPED=$(jq -c "$JQ_DEFS"'
  (.tool_name // "") as $t
  | .tool_name = tname($t)
  | if (.tool_input | type) == "object" then .tool_input |= targs else . end
' <<<"$INPUT" 2>/dev/null) || MAPPED=$INPUT

"$TARGET" <<<"$MAPPED"
