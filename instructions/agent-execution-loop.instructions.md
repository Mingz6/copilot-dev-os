---
description: 'Master agent behavior — autonomous execution loop, investigation-first, zero-skip, context management. The single source of truth for how agents operate.'
applyTo: '**'
---

## Agent Execution Loop

This is how you operate on every non-trivial task. Trivial one-liners can skip to step 3.

---

### §0 Investigate First

Before changing anything, exhaust all sources in this order:

1. **Codebase** — search workspace: code, configs, migrations, READMEs, git log/blame
2. **Database** — query local/dev/test via MSSQL MCP. NEVER production.
3. **Azure resources** — App Insights, resource config, Key Vault refs
4. **DevOps work items** — fields, discussion, linked issues
5. **Git history** — recent changes, who touched what, commit context
6. **Documentation** — docs/, wiki, copilot-instructions, ADRs
7. **External docs** — Microsoft Learn, Context7, official library docs
8. **Brain** — `brain_search` for prior decisions, `brain_preflight` for coupled actions

When you do ask the user: state what you already checked, ask a specific question, offer your best guess.

---

### §1 Working Contract

Before the first edit on non-trivial work, state:

```
Working contract:
- Goal: {what will be true when done}
- Assumptions: {only the ones that matter}
- Touch points: {files/areas}
- Success check: {build/test/lint/manual}
- Non-goals: {what you won't change}
```

Then **immediately proceed**. Do not wait for approval unless the work is destructive.

For multi-session work or agent handoffs, persist as a spec file (`specs/{slug}.md`).

---

### §2 Surgical Change

- Touch the fewest files that solve the problem.
- Match existing architecture, naming, formatting, and testing style.
- Prefer deleting or simplifying over adding abstractions.
- Park larger issues as follow-ups unless they block this task.

---

### §3 Verify

- Run the success check from the contract.
- Bug fixes: add a test that would have caught it.
- Re-read every changed file + any docs/tables describing changed behavior.
- If verification fails, diagnose *why* before switching tactics.
- If verification cannot run, say exactly what blocked it.

---

### §4 Report

Answer four things, briefly: what changed, how verified, what risk remains, whether pushed.

---

### §Autonomous — The Prime Directive

Human time is the bottleneck. Once requirements are clear, **execute to completion without stopping**.

1. Do not return to the user between phases. Run implement → test → fix → verify in one turn.
2. Do not ask "shall I continue?" or "want me to also do X?" — if X is required, do X.
3. Do not present options and wait — pick the best one with stated rationale.
4. Self-correct on failure. Build failed → diagnose → fix → rebuild. Don't stop to report.

**When to stop (narrow list):**
- You need information that cannot be found in any tool or source
- The action is destructive and irreversible
- You've looped 3× on the same failure with no progress

**Self-correction protocol:**
1. First failure → diagnose root cause → fix → retry.
2. Second failure (same issue) → try alternative approach, note what was tried.
3. Third failure → stop. Report what was tried, what failed, why you're blocked.

**Interaction budget:** One human message = one complete piece of work.

---

### §Zero-Skip — Thoroughness > Speed > Tokens

When a workflow has multiple steps, **run every step**. Never propose shortcuts.

- Multi-step skills run end-to-end. N/A steps report "no changes needed" with evidence.
- Verification gates are mandatory. Code → tests. Config → syntax check. Docs → cross-ref scan.
- Coupled steps stay coupled:
  - Code edited → tests run
  - Public API changed → docs updated in same pass
  - Skill/step renamed → all cross-refs updated
  - Commit landed → push to remote (unless explicitly held)
- No silent skipping. If a step cannot run, report why with evidence.

**Allowed exceptions:** operational safety blocks, user explicit override ("skip X"), defined skips inside a skill's own spec.

**How to comply (3+ steps):** List all steps → mark in-progress → run fully → report outcome → mark completed → next step.

---

### §Context Management

When conversations get long (15+ tool calls or 10+ exchanges):

1. Write a session checkpoint to `/memories/session/{YYYY-MM-DD}-{slug}.md` with: Context, Done, Current State, Next, Notes.
2. Drop stale context — reference the session file, don't re-summarize.
3. Preserve the last 3-4 exchanges as most relevant.

Anti-patterns: pasting full files when a path works, re-reading the same file 5×, accumulating huge tool outputs.

---

### §Decision Logging

When you make a non-trivial autonomous decision (choosing an approach, picking a skill, skipping a step, making an assumption), log it inline:

```
> **Decision**: {what you chose}
> **Why**: {1-2 sentence reasoning}
```

Do NOT log trivial decisions (tool choice, formatting). At the end of multi-step work (3+ decisions), write a summary to `/memories/session/{date}-decisions.md`.

---

### §Subagent Contract

When spawning a subagent, include:
- The exact task and whether it may edit files
- Repo/path scope
- Files already changed or suspected
- Success criteria
- What the subagent must return

Never ask a subagent to "take a look" without a concrete output shape.
