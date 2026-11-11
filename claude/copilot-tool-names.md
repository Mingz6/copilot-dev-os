# Copilot tool names, in Claude Code

The rules, agents and skills from copilot-dev-os were written for GitHub Copilot in VS Code. They
apply here unchanged; read their tool names this way:

| The rules say | In Claude Code |
|---|---|
| `run_in_terminal`, `execution_subagent` | Bash |
| `read_file`, `list_dir` | Read, Glob |
| `grep_search`, `file_search`, `semantic_search` | Grep, Glob |
| `create_file`, `replace_string_in_file`, `multi_replace_string_in_file` | Write, Edit |
| `get_errors` | the build, linter or type checker, run in Bash |
| `runSubagent` with `agentName` | the Agent tool with `subagent_type`; the agents are in `~/.claude/agents/` |
| `model: "Claude Opus ... (copilot)"`, `"Claude Sonnet ... (copilot)"` | `model: "opus"`, `"sonnet"` |
| `manage_todo_list` | TodoWrite |
| `vscode_askQuestions` | AskUserQuestion |
| `fetch_webpage` | WebFetch |
| `task_complete` | not needed: the final report ends the turn |
| `mcp_<server>_<tool>` | `mcp__<server>__<tool>` |
| `/memories/<file>` (the Copilot memory tool) | your auto memory, or a file in the project |
| a skill by name (`/tdd`, `/long-run`) | the same skill, from `~/.claude/skills/` |

The Stop hook runs here too, through `hooks/scripts/claude-adapter.sh`: it sends you back when you
edited code and ran nothing that checks it, or when you ended on a question you could have answered.
