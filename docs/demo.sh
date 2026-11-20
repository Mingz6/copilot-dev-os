#!/usr/bin/env bash
# What the Stop hook does, without an editor: feed it three made-up agent transcripts and print its
# answer. Installs into a throwaway HOME, so nothing on your machine changes. Needs jq.
# Recorded into docs/demo.gif by docs/demo.tape.

set -euo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export TMPDIR=$SANDBOX COPILOT_HOOK_LOG_DIR=$SANDBOX/logs
STOP=$SANDBOX/.copilot/hooks/scripts/stop.sh

step() { printf '\n\033[1m%s\033[0m\n' "$1"; }
event() { jq -cn --arg type "$1" --argjson data "$2" '{type: $type, data: $data}'; }
run_stop() { # run_stop <session> <event>... : write the transcript, ask the hook, print its verdict
  local session=$1 t=$SANDBOX/$1.jsonl out
  shift
  printf '%s\n' "$@" >"$t"
  out=$(jq -cn --arg t "$t" --arg s "$session" '{session_id: $s, transcript_path: $t, stop_hook_active: false}' | "$STOP")
  if [[ -z "$out" ]]; then
    printf '  \033[32mstop allowed\033[0m\n'
  else
    # First sentence of the reason the agent gets back, wrapped for the terminal.
    printf '  \033[31mblocked:\033[0m %s\n' "$(jq -r '.hookSpecificOutput.reason' <<<"$out" | sed 's/\. .*/./' | fold -s -w 90 | sed '1!s/^/           /')"
  fi
}

step "$ HOME=<sandbox> ./install.sh copilot"
HOME=$SANDBOX "$REPO/install.sh" copilot | tail -1

step "1. The agent edits parser.py and tries to end the turn"
run_stop edit \
  "$(event user.message '{"content": "fix the date parser"}')" \
  "$(event tool.execution_start '{"toolName": "replace_string_in_file", "arguments": {"filePath": "src/parser.py"}}')"

step "2. It ran pytest after the edit, then ends with \"Want me to open the PR?\""
run_stop offer \
  "$(event user.message '{"content": "fix the date parser"}')" \
  "$(event tool.execution_start '{"toolName": "replace_string_in_file", "arguments": {"filePath": "src/parser.py"}}')" \
  "$(event tool.execution_start '{"toolName": "run_in_terminal", "arguments": {"command": "pytest -q"}}')" \
  "$(event assistant.message '{"content": "Fixed and tested. Want me to open the PR?"}')"

step "3. It opened the PR itself and reports what changed"
run_stop finished \
  "$(event user.message '{"content": "fix the date parser"}')" \
  "$(event tool.execution_start '{"toolName": "replace_string_in_file", "arguments": {"filePath": "src/parser.py"}}')" \
  "$(event tool.execution_start '{"toolName": "run_in_terminal", "arguments": {"command": "pytest -q"}}')" \
  "$(event assistant.message '{"content": "Changed: src/parser.py. Checked: 42 tests pass. Opened PR #12."}')"
