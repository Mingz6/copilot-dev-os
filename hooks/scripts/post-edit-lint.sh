#!/bin/bash
# PostToolUse hook: after a file edit, run a fast syntax check for that file type and hand any
# error back to the model so it fixes it before moving on. It never blocks the edit, and a
# problem inside the hook itself is swallowed rather than surfaced as a tool error.

set -uo pipefail
export LC_ALL=en_US.UTF-8

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null)
case "$TOOL" in
  create_file|replace_string_in_file|multi_replace_string_in_file|edit_notebook_file) ;;
  *) exit 0 ;;
esac

PATHS=$(jq -r '.tool_input | (.filePath // .file_path // empty), (.replacements[]?.filePath // empty)' <<<"$INPUT" 2>/dev/null | sort -u)
[[ -n "$PATHS" ]] || exit 0

python_has() { python3 -c "import $1" >/dev/null 2>&1; }

# JSON files that allow comments, where jq would report false errors.
is_jsonc() {
  case "$1" in
    */tsconfig*.json|*/jsconfig*.json|*/.vscode/*.json|*/settings.json|*/keybindings.json|*/mcp.json|*/devcontainer.json|*/.eslintrc.json|*.code-workspace) return 0 ;;
  esac
  return 1
}

check_file() {
  local f=$1
  [[ -f "$f" ]] || return 0
  case "$f" in
    *.py|*.pyi)
      python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1])' "$f" 2>&1 | tail -n 3 ;;
    *.sh|*.bash)
      bash -n "$f" 2>&1 | head -n 3 ;;
    *.zsh)
      command -v zsh >/dev/null && zsh -n "$f" 2>&1 | head -n 3 ;;
    *.json)
      is_jsonc "$f" || jq empty "$f" 2>&1 | head -n 3 ;;
    *.yml|*.yaml)
      python_has yaml && python3 -c 'import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1], encoding="utf-8")))' "$f" 2>&1 | tail -n 3 ;;
    *.plist)
      command -v plutil >/dev/null && { plutil -lint -s "$f" 2>&1 | head -n 3; } ;;
    */SKILL.md|*.instructions.md|*.agent.md|*.prompt.md)
      python_has yaml && python3 - "$f" <<'PY' 2>&1 | tail -n 3
import re, sys, yaml
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if not m:
    sys.exit(f"{path}: no YAML frontmatter between --- lines, so it won't load")
try:
    data = yaml.safe_load(m.group(1)) or {}
except yaml.YAMLError as e:
    sys.exit(f"{path}: frontmatter is not valid YAML, so it won't load: {e}".splitlines()[0])
if path.endswith("SKILL.md"):
    missing = [k for k in ("name", "description") if not data.get(k)]
    if missing:
        sys.exit(f"{path}: frontmatter is missing {', '.join(missing)}")
PY
      ;;
  esac
}

REPORT=""
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  ERR=$(check_file "$f" 2>/dev/null) || true
  [[ -n "$ERR" ]] && REPORT+="${f}:"$'\n'"${ERR}"$'\n'
done <<<"$PATHS"

if [[ -n "$REPORT" ]]; then
  jq -n --arg ctx "Syntax check failed after this edit. Fix it before moving on."$'\n'"$REPORT" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
fi
exit 0
