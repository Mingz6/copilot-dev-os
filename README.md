# copilot-dev-os

A personal developer OS for VS Code Copilot — a set of instructions, agents, and skills that turn Copilot into a specialized engineering partner. Fork it, replace the examples with your own stack, and get something that actually knows your workflow.

## What's in here

```
instructions/   — Always-on rules wired into every Copilot session
agents/         — Custom agent modes for specific job types
skills/         — Multi-step workflow playbooks invoked by name
delegate/       — Persistent task queue (queue/, done/, active/)
```

### Instructions (`.instructions.md`)

Rules Copilot follows on every response — coding standards, voice rules, execution loop behavior. Key ones:

| File | What it does |
|------|-------------|
| `agent-execution-loop.instructions.md` | Autonomous execution contract — investigate first, work to completion, no interruptions |
| `think-deeper.instructions.md` | FAANG+ baseline — verify, hunt bugs, second-order thinking |
| `anti-ai-voice.instructions.md` | Ban AI-sounding phrases — keep output sounding human |
| `model-preference.instructions.md` | Claude tier policy — Claude Sonnet 4.6 floor, never non-Claude |
| `code-quality-gate.instructions.md` | Mandatory security + test gate on every code change |
| `git-workflow.instructions.md` | Commit message standards, branch hygiene |
| `clean-code.instructions.md` | Universal clean code rules across all languages |
| `sdd.instructions.md` | Spec-Driven Development — persist requirements before coding |
| `typescript-5-es2022.instructions.md` | TypeScript strict mode, ES2022, no `any` |
| `reactjs.instructions.md` | React 18 hooks, components, state, performance |
| `csharp.instructions.md` | C#/.NET standards — async, DI, Result pattern |
| `python.instructions.md` | Python 3.11+ — type hints, Pydantic, async, httpx |
| `api-design.instructions.md` | REST conventions, pagination, response formats |
| `error-handling.instructions.md` | Result pattern, ProblemDetails, circuit breakers |
| `observability.instructions.md` | Structured logging, tracing, health checks, App Insights |
| `ms-sql-dba.instructions.md` | SQL Server — safe scripts, schema verification |
| `mcp-server-design.instructions.md` | MCP server patterns — typed contracts, deny-by-default |
| `markdown.instructions.md` | Docs standards — headings, frontmatter, links |
| `self-explanatory-code-commenting.instructions.md` | Comment only what code can't say itself |
| `context-glossary.instructions.md` | Per-repo `CONTEXT.md` domain glossary convention |

### Agents (`.agent.md`)

Custom Copilot agent modes — each one is a specialized engineer:

| Agent | Purpose |
|-------|---------|
| `zero-interrupt-orchestrator` | Fully autonomous — implement → test → fix → verify, no stops |
| `code-perfectionist` | New features with 5-phase validation: security, clean code, tests, build, bug hunt |
| `csharp-dotnet-janitor` | Cleanup passes — dead code, warnings, modernize syntax |
| `pr-reviewer` | Multi-perspective code review — correctness, quality, security, architecture |
| `pr-fix-coordinator` | Apply PR feedback, fix CI failures, resolve merge conflicts |
| `ms-sql-dba` | T-SQL queries, stored procs, index design, performance tuning |
| `expert-react-frontend-engineer` | React 18, TypeScript, Nx monorepo, Fluent UI, testing |
| `se-security-reviewer` | OWASP Top 10, Zero Trust, LLM security, enterprise hardening |
| `azure-principal-architect` | Azure WAF — reliability, security, cost optimization |
| `github-actions-expert` | Secure CI/CD — action pinning, OIDC auth, least privilege |
| `polyglot-build-runner` | Run builds and report results for any language |
| `delegate-coordinator` | Run the `/delegate` skill — task queue management |
| `flywheel` | Continuous improvement — absorb patterns from repos, optimize config |

### Skills (`skills/{name}/SKILL.md`)

Multi-step workflow playbooks triggered by name (e.g., `/diagnose`, `/tdd`):

| Skill | When to use |
|-------|-------------|
| `delegate` | Persistent task queue — capture work, pick up tasks, manage queue |
| `diagnose` | Structured debug loop — reproduce → hypothesize → fix → regression test |
| `tdd` | Red-green-refactor TDD loop — write failing test first |
| `grill-me` | Interrogate your plan until all decision branches are resolved |
| `deploy-verify` | Smoke-test a live environment after deploy or stakeholder report |
| `flywheel` | Scout repos, absorb patterns, optimize Copilot config |
| `documentation-writer` | Diátaxis-style docs — tutorials, how-to guides, references, explanations |
| `csharp-toolkit` | C#/.NET reference — patterns, async, xUnit, DI, XML docs |
| `sql-toolkit` | SQL Server code review and performance optimization |
| `performance-optimization` | Cross-stack performance — frontend, backend, database |
| `javascript-typescript-jest` | Jest/Vitest patterns — mocking, async tests, snapshots |
| `python-fastapi-pytest` | pytest patterns — fixtures, async tests, Azure OpenAI mocking |
| `nuget-manager` | Add/update/remove NuGet packages via `dotnet` CLI |
| `microsoft-docs` | Query Microsoft Learn + Context7 to verify SDK usage |
| `appinsights-instrumentation` | Wire Application Insights — requests, dependencies, exceptions |

### Delegate queue (`delegate/`)

A file-based task queue:
- `delegate/queue/` — pending tasks
- `delegate/active/` — in-progress
- `delegate/done/` — completed (compacted monthly)

See [delegate/README.md](delegate/README.md) for full instructions.

## How to fork and use

1. Fork or clone this repo
2. Point VS Code's `github.copilot.chat.codeGeneration.instructions` at `instructions/`
3. Drop `.agent.md` files in your `.github/` or user config folder
4. Register skills by adding them to your user prompt files or Copilot instructions
5. Replace any placeholder stack references (`your-org`, `your-api`, `your-app.com`) with your actual project names
6. Add your own instructions for stack-specific patterns your team follows

## Philosophy

- **Instructions over prompts** — encode standards as persistent rules, not one-off reminders
- **Investigate first** — exhaust code, logs, and docs before asking
- **Human time is the bottleneck** — execute to completion, only stop for genuinely missing info
- **Quality over speed** — verify, hunt bugs, update docs in the same pass
- **No AI voice** — every output sounds like a developer, not a chatbot
