---
description: 'Model preference — tiered Claude-only policy. Opus 4.7 default for complex work, Opus 4.6 for solid mid-tier, Sonnet 4.6 floor for narrow tasks. NEVER GPT or any non-Claude model. Applies universally to main agents and subagents.'
applyTo: '**'
---

## Model Preference (highest priority)

**Use the right Claude tier for the task. Never go below Sonnet 4.6. Never use a non-Claude model.**

### The allowed tiers (in this order)

| Tier | Model | Use for |
|------|-------|---------|
| Top  | **Claude Opus 4.7 (copilot)** | Complex reasoning, multi-file refactors, architecture decisions, security review, code review, debugging non-trivial bugs, planning multi-step skills (`/flywheel`, `/delegate` planning), any "think hard" work. |
| Mid  | **Claude Opus 4.6 (copilot)** | Solid implementation default. Most feature work, tests, docs writing, daily work, well-scoped subagent tasks where Opus 4.7 is overkill. |
| Floor | **Claude Sonnet 4.6 (copilot)** | Narrow, mechanical tasks: single-file lookups, formatting passes, simple extraction, "read this file and tell me X", terminal command suggestions, status summaries. Worst case only. |

**Hard rule:** below Sonnet 4.6 is forbidden. Non-Claude models (GPT, Gemini, Mistral, Llama, Grok, DeepSeek), "Auto" selection, and any `mini`/`flash`/`nano`/`lite`/`turbo` variants are all forbidden.

### Rules

1. **Main chat session** — user picks the tier. Default Opus 4.7. Don't second-guess the user's selection downward.
2. **Subagents** — pick the tier that fits the task, not the orchestrator's tier. Pass the chosen tier explicitly to `runSubagent` via the `model` field. Examples:
   - "Scan 50 files for a pattern" -> Sonnet 4.6.
   - "Implement this feature with tests" -> Opus 4.6.
   - "Review this PR for security/architecture" -> Opus 4.7.
   - When in doubt, go up a tier, not down.
3. **Custom agents** — every `.agent.md` declares a tier in frontmatter that matches its purpose:
   - Heavy-thinking agents (Code Perfectionist, PR Reviewer, SE: Security, Azure Principal Architect) -> Opus 4.7.
   - Implementation/coordination agents (mostDelegate Coordinator, Standup Coach, PR Fix) -> Opus 4.6 acceptable; Opus 4.7 if naturally complex.
   - Lookup/scan agents (Explore, Polyglot Build Runner) -> Sonnet 4.6 acceptable.
4. **VS Code model picker / CLI config** — same allow-list. Never set defaults to anything outside the three tiers.

### Tier-selection heuristic for subagents

Ask in this order:

1. Does the task require multi-step reasoning, cross-file synthesis, or judgement calls? -> **Opus 4.7**.
2. Is it a well-scoped implementation, doc, or test where the path is clear? -> **Opus 4.6**.
3. Is it a mechanical scan, lookup, or single-shot extraction? -> **Sonnet 4.6**.
4. Anything else -> **Opus 4.7** (default up, never down).

### Reference

- Related: `agent-execution-loop.instructions.md` §Zero-Skip — quality > speed > token cost
- Related: `think-deeper.instructions.md` — FAANG+ rigor requires the right reasoning tier
- VS Code docs: [Custom agents](https://code.visualstudio.com/docs/copilot/customization/custom-agents) §Header — `model` field
