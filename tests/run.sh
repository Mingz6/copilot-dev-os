#!/usr/bin/env bash
# Tests for the hooks, the installer and the file formats. Needs bash, jq and python3.
# Run from anywhere: bash tests/run.sh

set -uo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOKS=$REPO/hooks/scripts
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export TMPDIR=$WORK COPILOT_HOOK_LOG_DIR=$WORK/logs
PASS=0 FAIL=0

ok() { PASS=$((PASS + 1)); echo "ok   $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL $1"; [[ -z "${2:-}" ]] || printf '     %s\n' "${2//$'\n'/$'\n     '}"; }
# expect <name> <jq filter that must be true> <output>
expect() { if jq -e "$2" >/dev/null 2>&1 <<<"$3"; then ok "$1"; else bad "$1" "$3"; fi; }
expect_empty() { if [[ -z "$2" ]]; then ok "$1"; else bad "$1" "$2"; fi; }

# A VS Code style transcript: one JSON event per line.
transcript() { # transcript <file> <event>...
  local f=$1; shift
  : >"$f"
  for e in "$@"; do printf '%s\n' "$e" >>"$f"; done
}
user_msg() { jq -cn --arg t "$1" '{type: "user.message", data: {content: $t}}'; }
assistant_msg() { jq -cn --arg t "$1" '{type: "assistant.message", data: {content: $t}}'; }
tool_call() { jq -cn --arg n "$1" --argjson a "$2" '{type: "tool.execution_start", data: {toolName: $n, arguments: $a}}'; }
stop_input() { jq -cn --arg t "$1" --arg s "${2:-s1}" '{hook_event_name: "Stop", session_id: $s, transcript_path: $t, stop_hook_active: false}'; }

echo "# post-edit-lint.sh"
printf 'if then\n' >"$WORK/broken.sh"
printf 'echo fine\n' >"$WORK/fine.sh"
out=$(jq -cn --arg f "$WORK/broken.sh" '{tool_name: "create_file", tool_input: {filePath: $f}}' | "$HOOKS/post-edit-lint.sh")
expect "broken shell script is handed back to the model" '.hookSpecificOutput.additionalContext | test("Syntax check failed")' "$out"
out=$(jq -cn --arg f "$WORK/fine.sh" '{tool_name: "create_file", tool_input: {filePath: $f}}' | "$HOOKS/post-edit-lint.sh")
expect_empty "valid shell script passes silently" "$out"
out=$(jq -cn '{tool_name: "run_in_terminal", tool_input: {command: "ls"}}' | "$HOOKS/post-edit-lint.sh")
expect_empty "non-edit tools are ignored" "$out"

echo "# verify-edits.sh"
T=$WORK/edit-only.jsonl
transcript "$T" "$(user_msg 'fix the parser')" "$(tool_call create_file '{"filePath":"/x/app.py"}')"
out=$(stop_input "$T" edit-only | "$HOOKS/verify-edits.sh")
expect "code edit with no check after it is blocked" '.hookSpecificOutput.decision == "block"' "$out"
out=$(stop_input "$T" edit-only | "$HOOKS/verify-edits.sh")
expect_empty "the same edit is not blocked twice" "$out"
T=$WORK/edit-tested.jsonl
transcript "$T" "$(user_msg 'fix the parser')" "$(tool_call create_file '{"filePath":"/x/app.py"}')" \
  "$(tool_call run_in_terminal '{"command":"pytest -q"}')"
out=$(stop_input "$T" edit-tested | "$HOOKS/verify-edits.sh")
expect_empty "edit followed by pytest passes" "$out"
T=$WORK/docs-only.jsonl
transcript "$T" "$(user_msg 'update the readme')" "$(tool_call create_file '{"filePath":"/x/README.md"}')"
out=$(stop_input "$T" docs-only | "$HOOKS/verify-edits.sh")
expect_empty "docs-only edits pass" "$out"

echo "# stop-keep-going.sh"
T=$WORK/offer.jsonl
transcript "$T" "$(user_msg 'ship it')" "$(assistant_msg 'Pushed the branch. Want me to open the PR as well?')"
out=$(stop_input "$T" | "$HOOKS/stop-keep-going.sh")
expect "ending on an offer is sent back" '.hookSpecificOutput.decision == "block"' "$out"
T=$WORK/paused.jsonl
transcript "$T" "$(user_msg 'ship it')" "$(assistant_msg '⏸ The deploy needs your production approval in the portal.')"
out=$(stop_input "$T" | "$HOOKS/stop-keep-going.sh")
expect_empty "a ⏸ line passes" "$out"
out=$(jq -cn --arg t "$WORK/offer.jsonl" '{transcript_path: $t, stop_hook_active: true}' | "$HOOKS/stop-keep-going.sh")
expect_empty "never blocks twice in a row (stop_hook_active)" "$out"

echo "# stop.sh"
T=$WORK/both.jsonl
transcript "$T" "$(user_msg 'fix it')" "$(tool_call create_file '{"filePath":"/x/app.ts"}')" \
  "$(assistant_msg 'Done. Should I run the tests too?')"
out=$(stop_input "$T" both | "$HOOKS/stop.sh")
expect "dispatcher returns the verify block first" '.hookSpecificOutput.reason | test("^Verify round")' "$out"
out=$(stop_input "$T" both | "$HOOKS/stop.sh")
expect "then the keep-going block" '.hookSpecificOutput.reason | test("offering a next step")' "$out"
if [[ $(wc -l <"$COPILOT_HOOK_LOG_DIR/stop.log") -eq 2 ]]; then ok "each block is logged"; else bad "each block is logged" "$(cat "$COPILOT_HOOK_LOG_DIR/stop.log")"; fi

echo "# long-run-continue.sh"
mkdir -p "$WORK/repo/specs"
SPEC=$WORK/repo/specs/feature.md
printf '# Feature\n\n**Status:** in-progress\n\n- [x] one\n- [ ] two\n' >"$SPEC"
T=$WORK/long.jsonl
transcript "$T" "$(user_msg 'go')" "$(tool_call replace_string_in_file "$(jq -cn --arg f "$SPEC" '{filePath: $f}')")"
out=$(stop_input "$T" long | "$HOOKS/long-run-continue.sh")
expect "in-progress spec keeps the run going" '.decision == "block" and (.reason | test("1 unchecked"))' "$out"
out=$(stop_input "$T" long | "$HOOKS/long-run-continue.sh")
expect_empty "an untouched spec lets a stuck run stop" "$out"
sed -i.bak 's/in-progress/completed/' "$SPEC"
out=$(stop_input "$T" long2 | "$HOOKS/long-run-continue.sh")
expect_empty "a completed spec stops" "$out"

echo "# claude-adapter.sh"
out=$(jq -cn --arg f "$WORK/broken.sh" '{hook_event_name: "PostToolUse", tool_name: "Write", tool_input: {file_path: $f}}' | "$HOOKS/claude-adapter.sh" post-edit-lint.sh)
expect "Claude's Write maps to the lint hook" '.hookSpecificOutput.additionalContext | test("Syntax check failed")' "$out"
CT=$WORK/claude.jsonl
{
  jq -cn '{type: "user", message: {content: "fix the bug"}}'
  jq -cn '{type: "assistant", message: {content: [{type: "tool_use", id: "t1", name: "Edit", input: {file_path: "/x/app.go", old_string: "a", new_string: "b"}}]}}'
  jq -cn '{type: "assistant", message: {content: [{type: "text", text: "Fixed."}]}}'
} >"$CT"
out=$(jq -cn --arg t "$CT" '{hook_event_name: "Stop", session_id: "c1", transcript_path: $t, stop_hook_active: false}' | "$HOOKS/claude-adapter.sh" stop.sh)
expect "Claude transcript: unverified edit blocks in Claude's shape" '.decision == "block" and (.reason | test("app.go"))' "$out"

echo "# install.sh"
H=$WORK/home
mkdir -p "$H"
if HOME=$H "$REPO/install.sh" copilot >/dev/null; then ok "copilot install"; else bad "copilot install"; fi
n=$(find "$H/.copilot" -type l | wc -l | tr -d ' ')
want=$(find "$REPO/instructions" "$REPO/agents" "$REPO/hooks" -type f \( -name '*.md' -o -name '*.json' -o -name '*.sh' \) | wc -l)
want=$((want + $(find "$REPO/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)))
if [[ $n -eq $want ]]; then ok "one link per file ($n)"; else bad "one link per file" "got $n, want $want"; fi
broken=$(find -L "$H/.copilot" -type l)
expect_empty "no dangling links" "$broken"
out=$(HOME=$H "$REPO/install.sh" copilot 2>&1 | tail -1)
if [[ $out == *"(0 change(s))"* ]]; then ok "second run changes nothing"; else bad "second run changes nothing" "$out"; fi
mkdir -p "$H/.claude"
echo '{"model": "opus", "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo mine"}]}]}}' >"$H/.claude/settings.json"
if HOME=$H "$REPO/install.sh" claude >/dev/null && HOME=$H "$REPO/install.sh" claude >/dev/null; then ok "claude install, twice"; else bad "claude install, twice"; fi
s=$(cat "$H/.claude/settings.json")
expect "settings keep the user's own hook and model" '.model == "opus" and ([.hooks.Stop[].hooks[].command] | index("echo mine") != null)' "$s"
expect "our hooks are added once" '([.hooks.Stop[].hooks[].command | select(test("claude-adapter"))] | length) == 1 and ([.hooks.PostToolUse[].hooks[].command | select(test("claude-adapter"))] | length) == 1' "$s"
if head -2 "$H/.claude/agents/se-security-reviewer.md" | grep -qx 'name: se-security-reviewer'; then ok "agents get a Claude name"; else bad "agents get a Claude name" "$(head -5 "$H/.claude/agents/se-security-reviewer.md")"; fi
if grep -q '^  - "\*\*/\*.py"$' "$H/.claude/rules/python.md"; then ok "applyTo becomes paths"; else bad "applyTo becomes paths" "$(head -5 "$H/.claude/rules/python.md")"; fi
if ! head -1 "$H/.claude/rules/agent-execution-loop.md" | grep -q '^---'; then ok "applyTo ** becomes an always-on rule"; else bad "applyTo ** becomes an always-on rule"; fi
echo "mine" >"$H/.claude/rules/tdd.md" && rm "$H/.claude/skills/tdd" && mkdir "$H/.claude/skills/tdd"
if HOME=$H "$REPO/install.sh" claude >/dev/null 2>&1; then bad "a file of yours is reported, not overwritten"; else
  if [[ $(cat "$H/.claude/rules/tdd.md") == mine ]]; then ok "a file of yours is reported, not overwritten"; else bad "a file of yours is reported, not overwritten"; fi
fi
HOME=$H "$REPO/install.sh" uninstall >/dev/null
left=$(find "$H/.copilot" "$H/.claude" -type l; grep -rl "generated by copilot-dev-os" "$H/.claude" 2>/dev/null)
expect_empty "uninstall removes every link and generated file" "$left"
s=$(cat "$H/.claude/settings.json")
expect "uninstall removes our hooks and keeps yours" '([.. | .command? // empty | select(test("claude-adapter"))] | length) == 0 and .hooks.Stop[0].hooks[0].command == "echo mine"' "$s"

echo "# file formats"
for f in "$REPO"/skills/*/SKILL.md; do
  name=$(sed -n 's/^name: *//p' "$f" | head -1)
  dir=$(basename "$(dirname "$f")")
  if [[ $name == "$dir" ]]; then ok "skill $dir: name matches folder"; else bad "skill $dir: name matches folder" "name: $name"; fi
done
out=$(python3 - "$REPO" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
for p in sorted([*root.glob("instructions/*.md"), *root.glob("agents/*.md"), *root.glob("skills/*/SKILL.md")]):
    m = re.match(r"^---\n(.*?)\n---\n", p.read_text(encoding="utf-8"), re.S)
    keys = set(re.findall(r"^([A-Za-z][\w-]*):", m.group(1), re.M)) if m else set()
    need = {"applyTo"} if p.parent.name == "instructions" else {"description"}
    if p.name == "SKILL.md":
        need = {"name", "description"}
    if not m or need - keys:
        print(f"{p.relative_to(root)}: frontmatter missing {sorted(need - keys) or 'block'}")
PY
)
expect_empty "every instruction, agent and skill has its frontmatter keys" "$out"

echo
echo "$PASS passed, $FAIL failed"
((FAIL == 0))
