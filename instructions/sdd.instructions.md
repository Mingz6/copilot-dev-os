---
description: 'Spec-Driven Development — persist requirements as versioned spec files before coding. Use for features, multi-session work, and AI agent handoffs. Lightweight alternative to full Working Contract for larger scope.'
applyTo: '**/specs/**'
---

## Spec-Driven Development (SDD)

Write the spec before writing the code. Specs are cheap to change; code is not.

### When to Use SDD vs Working Contract

| Scope | Use |
|---|---|
| Single-session fix, bug, small change | Working Contract in chat (see `agent-execution-loop.instructions.md`) |
| Multi-session feature, new domain, refactor | Full SDD — persist spec to file |
| AI agent handoff (Code Perfectionist, Delegate) | Full SDD — agent reads the spec file as context |

If you're not sure, default to Working Contract. Upgrade to SDD when the work survives past one chat session.

### The Three Phases

#### 1. Specify — What and Why

Write `specs/{feature-slug}.md` in the project root. Cover:

- **Goal**: one sentence — what's true when this is done
- **Motivation**: why this matters (link work item if applicable)
- **Requirements**: numbered list of must-haves
- **Non-goals**: what you're explicitly not doing
- **Edge cases**: the things that break if you don't think about them
- **Acceptance criteria**: how to verify it works

Commit the spec. It's a first-class artifact, not a scratch pad.

#### 2. Plan — How

Add a `## Technical Plan` section to the same spec file, or create `specs/{feature-slug}-plan.md`. Cover:

- Architecture decisions (which layers, which patterns)
- Data model changes (new tables, columns, migrations)
- API surface (endpoints, contracts, breaking changes)
- Dependencies (libraries, services, infrastructure)
- Risk areas (performance, security, backward compat)

This replaces the Working Contract's "Touch points" and "Assumptions" for larger work.

#### 3. Tasks — Breakdown

Add a `## Tasks` section or create `specs/{feature-slug}-tasks.md`. Each task should be:

- Small enough for one agent session or one focused coding block
- Ordered by dependency (what must be done first)
- Checkboxable (`- [ ]` in markdown)

```markdown
## Tasks
- [ ] Add table to database (DDL script)
- [ ] Create `REGI.Notification.Service` with Dapper queries
- [ ] Add `GetPreferences` / `UpdatePreferences` endpoints
- [ ] Wire React hook in frontend app
- [ ] Add tests for edge cases (no prefs set, invalid channel)
```

### Constitution = copilot-instructions.md

SDD's "constitution" concept maps to the per-repo `copilot-instructions.md` files you already have. No need to duplicate — your existing project instructions *are* the constitution.

### Rules

1. **Spec before code.** Don't start coding a multi-session feature without a spec file committed.
2. **Spec is living.** Update it when requirements change. It's not a contract frozen in time.
3. **Spec is reviewable.** PRs can include spec changes. Teammates can review the plan before you write a line of code.
4. **Agent context.** When spawning a subagent for a feature, point it at the spec file: "Read `specs/notification-prefs.md` and implement task 3."
5. **Clean up.** When a feature ships and the spec is fully implemented, move it to `specs/_done/` or delete it. Stale specs are worse than no specs.

### Spec File Template

Use this structure for `specs/{feature-slug}.md`: Goal, Motivation, Requirements, Non-Goals, Edge Cases, Acceptance Criteria, Technical Plan, Tasks. Add `Card: AB#{id}`, `Status: draft|implementing|done`, `Date:` at the top.

### ADRs — Companion to Specs

Specs capture WHAT to build. ADRs capture WHY a particular approach was chosen over alternatives. They live in `docs/adr/` and survive past feature completion (unlike specs which move to `_done/`).

- Only create when: hard to reverse + surprising without context + real trade-off existed
- Format and rules: see `context-glossary.instructions.md`
- Specs reference ADRs: "See ADR-0003 for why we chose event sourcing here"
- ADRs reference specs: "Implemented in specs/notification-prefs.md"

### The Grill → Spec → TDD Pipeline

For maximum precision, chain these skills:

1. **`/grill-me`** — interrogate until requirements are crystal clear
2. **SDD spec** — persist the decisions as a spec file
3. **`/tdd`** — implement with red-green-refactor vertical slices
4. **`/diagnose`** — if bugs surface, use the structured loop

This pipeline ensures you never code something you haven't thought through, and never ship something you haven't verified.

### Reference

- Extends: `agent-execution-loop.instructions.md` (Working Contract = lightweight SDD)
- Source: [GitHub Spec Kit](https://github.com/github/spec-kit) + [Microsoft Blog](https://developer.microsoft.com/blog/spec-driven-development-spec-kit)
- Related: `think-deeper.instructions.md` (verify, don't assume — specs force upfront thinking)
- Related: `agent-execution-loop.instructions.md` §Zero-Skip (spec → plan → tasks → implement — no skipping phases)
- Related: `context-glossary.instructions.md` (CONTEXT.md + ADR format)
- Related: `/grill-me` skill (interrogation that feeds into spec writing)
