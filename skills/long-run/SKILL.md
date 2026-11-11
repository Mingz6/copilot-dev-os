---
name: long-run
user-invocable: true
description: |
  Autonomous execution loop for multi-hour tasks. Chains: auto-grill → SDD spec → TDD → evaluator gate → diagnose → flywheel
  in a repeating loop until all evaluators pass. Runs in VS Code Copilot Chat (full MCP/browser/subagent access)
  or git worktree isolation for long jobs.
  Use when: '/long-run', 'autonomous mode', 'background build', 'fire and forget',
  'run this overnight', 'long job', 'keep going until done', 'loop until perfect',
  'full pipeline', 'end to end autonomous'.
---

# Long Run — Autonomous Execution Loop

Chain skills in a repeating loop until all evaluators pass. The agent executes autonomously — no human interaction after the initial trigger unless genuinely blocked after exhausting all sources.

## How it runs

- **In a normal chat** (you are not the Zero-Interrupt Orchestrator): don't run the loop yourself. Write a brief with the goal, repo path, spec path if one exists, and what "done" means. Then hand the whole job to `runSubagent` with `agentName: "Zero-Interrupt Orchestrator"`. It works in its own context on Opus 5.5 (its agent pin) and can't stop to ask the user anything. When it returns, re-run the build and tests yourself, then report.
- **As the orchestrator:** run the loop below. Keep the spec's `**Status:**` honest: `in-progress` while work remains, `completed` when every evaluator passes, `blocked` plus a Progress Log reason for hard stops. A Stop hook sends you back to work while it says `in-progress`.

## Core Principle: Single Living Document

One file per task: `specs/{slug}.md`. The agent creates it (contract + checklist) and updates it in-place (checks boxes, appends issues, writes feedback at the bottom). No separate `-checklist.md`, `-feedback.md`, `-decisions.md`, or `-checkpoint.md` — everything lives in **one file**.

Why: context fragmentation kills autonomous agents. One path to hand off, one file to resume from.

## The Loop

```
┌───────────────────────────────────────────────────────────────────┐
│                                                                   │
│   ┌──────────┐    ┌──────────┐    ┌─────────┐                    │
│   │AUTO-GRILL│───▶│  SPEC    │───▶│  TDD    │                    │
│   │(self-ask)│    │(generate)│    │(build)  │                    │
│   └──────────┘    └──────────┘    └─────────┘                    │
│                                       │                           │
│                                       ▼                           │
│   ┌──────────────── EVALUATOR GATE ────────────────┐             │
│   │  E1: Build          (exit 0)                   │             │
│   │  E2: Tests          (0 failures)               │             │
│   │  E3: Lint           (clean)                    │             │
│   │  E4: Smoke Test     (browser — no 500, no crash)│            │
│   │  E5: Code Quality   (subagent: read-only)      │             │
│   │  E6: Security       (subagent: SE: Security)   │             │
│   │  ALL PASS → flywheel → sweep → done check      │             │
│   │  ANY FAIL → diagnose → retry (max 6 iterations)│             │
│   └────────────────────────────────────────────────┘             │
│        │ pass                    │ fail                           │
│        ▼                         ▼                               │
│   ┌─────────┐              ┌─────────┐                           │
│   │FLYWHEEL │              │DIAGNOSE │──▶ fix ──▶ re-evaluate    │
│   │(absorb) │              │ (fix)   │                           │
│   └────┬────┘              └─────────┘                           │
│        ▼                                                         │
│   ┌─────────┐                                                    │
│   │ SWEEP   │ (run app, walk every route)                        │
│   └────┬────┘                                                    │
│        │ issues found? → fix → re-evaluate                       │
│        │ clean? → done                                           │
│        ▼                                                         │
│   ┌─────────┐                                                    │
│   │HANDOFF  │ report, commit, push                               │
│   └─────────┘                                                    │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Trigger

```
/long-run {task description}
/long-run {spec file path}
/long-run                      # picks up from specs/
```

## Phases (executed in order, looping)

### Phase 1: AUTO-GRILL (first iteration only)

The agent grills ITSELF — not the user. Self-answer all ambiguities by exhausting every source:

1. **Read the task/spec** — what's explicitly stated
2. **Scan codebase** — existing patterns, conventions, similar implementations
3. **Search memory** — prior decisions, instructions, CONTEXT.md
4. **Check git history** — recent changes, related work
5. **Fetch external docs** — Context7, Microsoft Learn if framework-specific
6. **List all ambiguities** — what's unclear or has multiple interpretations
7. **For each ambiguity, self-decide** with rationale (based on sources above)
8. **Write decisions** into `## Decisions` section of `specs/{slug}.md`

**Only ask the user when ALL of these are true:**
- The ambiguity is critical (wrong choice = wasted work)
- No source in codebase, docs, or git history resolves it
- Multiple interpretations are equally valid with no signal to pick one
- Ask ONE focused question max, with your recommended answer

**If you can find ANY signal in any source → just decide and log your rationale. Don't ask.**

**Skip condition:** If spec already exists with a `## Decisions` section, skip grilling.

### Phase 2: SPEC FILE (first iteration only — THE KEY OUTPUT)

Generate the single living document at `specs/{slug}.md`. The agent creates and updates it throughout execution.

**Template:**

```markdown
# {Task Title}

**Generated:** {ISO timestamp}
**Branch:** feat/{slug}
**Max iterations:** 6
**Status:** in-progress

---

## Decisions

- **{ambiguity 1}:** {chosen answer} — {rationale}
- **{ambiguity 2}:** {chosen answer} — {rationale}

---

## Checklist

### Pre-flight
- [ ] Branch created from main
- [ ] Dependencies installed
- [ ] Existing tests pass (baseline)
- [ ] .env verified (all required vars set)

### Phase A: {First logical chunk}

#### Implementation
- [ ] {Specific file to create/modify}: {what to do}
- [ ] {Next specific action}

#### Tests
- [ ] Test: {describe the behavior being tested}
- [ ] Test: {next behavior}

#### Gate
- [ ] All tests pass
- [ ] Lint clean
- [ ] Build succeeds
- [ ] Manual smoke: {specific thing to verify visually/functionally}

### Phase B: {Second logical chunk}
...{same structure}...

### Verification Sweep
- [ ] Start the app/service locally
- [ ] Navigate each major UI route/endpoint — note broken behavior
- [ ] Check: {specific known risk area 1}
- [ ] Check: {specific known risk area 2}
- [ ] Check: tabs/pages load correct data (not stale)
- [ ] Check: error states handled gracefully
- [ ] Run full test suite one final time

---

## Progress Log

<!-- Agent appends here as it works. Format: -->
<!-- **{timestamp} — Iteration {N}:** {what was done, what passed/failed} -->

---

## Known Issues

<!-- Agent appends issues as found. Keep this table growing. -->
| Issue | Severity | Location | Suggested Fix |
|-------|----------|----------|---------------|

---

## Verification Sweep Results

<!-- Agent fills this after Phase 6. -->
| Route/Feature | Status | Notes |
|---------------|--------|-------|

---

## Handoff

<!-- Agent writes this at the end (Phase 7). -->
```

**Rules for this file:**
- Everything above `## Progress Log` is the contract (written at creation)
- Agent updates checkboxes in-place (`[ ]` → `[x]`) as items complete
- Agent appends to Progress Log, Known Issues, Sweep Results, and Handoff
- ONE file. Both agents read and write it. No other spec files needed.
- Every checkbox is a **concrete, verifiable action** — not vague ("improve X")
- Implementation items reference specific files and what changes
- Verification Sweep items are **project-specific** — list actual routes/tabs/features

**Skip condition:** If `specs/{slug}.md` already exists and has unchecked items in `## Checklist`, resume from first unchecked item.

### Phase 3: TDD (every iteration)

For the current phase/item in the spec:
1. Write a failing test (RED)
2. Implement the minimum code to pass (GREEN)
3. Refactor if needed (REFACTOR)
4. Repeat for each behavior in the current scope

Follow vertical slices — one test, one implementation, move on.

### Phase 4: EVALUATOR GATE (every iteration — the quality wall)

Run ALL evaluators. Every one must pass before proceeding. This is what makes the output flawless.

| # | Evaluator | How to run | PASS condition |
|---|-----------|-----------|----------------|
| E1 | **Build** | `dotnet build` / `npm run build` / `docker build` | Exit 0, no errors |
| E2 | **Tests** | `dotnet test` / `pytest` / `npm test` | Exit 0, 0 failures, 0 skipped-unexpectedly |
| E3 | **Lint** | `ruff check .` / `npm run lint` / `dotnet format --verify-no-changes` | Exit 0, no warnings treated as errors |
| E4 | **Smoke Test** | Open browser → navigate critical paths | No 500s, no blank pages, no JS errors in console |
| E5 | **Code Quality** | Spawn a read-only review subagent with the changed files | No Critical or High findings |
| E6 | **Security** | Spawn subagent `SE: Security` with changed files | No OWASP violations, no exposed secrets |

**Execution rules:**
- E1-E3 run sequentially (fast, terminal-based)
- E4 runs only if the project has a UI/API (skip for pure libraries)
- E5-E6 run in parallel via `runSubagent` (fan-out)
- Each evaluator logs its result in the `## Progress Log`

**Result handling:**
- **ALL PASS** → proceed to Phase 5 (flywheel)
- **ANY FAIL** → proceed to Phase 4b (diagnose), then re-run ONLY the failed evaluators
- Log which evaluators passed/failed in the Progress Log entry

**Evaluator customization:** If the project has a `Makefile`, `justfile`, or `package.json` scripts section, use those commands. Adapt to the project — don't force a command that doesn't exist.

### Phase 4b: DIAGNOSE (on failure only)

Invoke `/diagnose` logic:
1. Build a feedback loop (the failing gate IS the loop)
2. Reproduce (run it, confirm it fails)
3. Hypothesize (read error, identify root cause)
4. Fix (surgical change)
5. Verify (re-run gate)

**Max 3 fix attempts per failure.** If still failing after 3, log the blocker and move to next item.

### Phase 5: FLYWHEEL (end of each iteration)

Quick self-improvement pass:
- Did I learn a pattern worth recording? → write to `/memories/`
- Did I make a mistake worth avoiding? → add to `/memories/mistakes.md`
- Is there dead code or tech debt I introduced? → clean up now

### Phase 6: VERIFICATION SWEEP (after all checklist items complete)

**This is the phase that catches what TDD misses.** Don't skip it.

The agent must **actually run the app/service and interact with it** — not just run tests.

1. **Start the service** (`docker compose up`, `python app.py`, `npm run dev`, etc.)
2. **Walk every route/tab/endpoint** listed in the checklist's Verification Sweep section
3. **For each, verify:**
   - Does it load without errors?
   - Does it show current/correct data (not stale, not empty)?
   - Does it handle edge cases (empty state, error state, loading state)?
4. **Log issues found** — add them as new checklist items under `## Sweep Fixes`
5. **Fix each issue** (TDD cycle: write a test that catches it, then fix)
6. **Re-run the sweep** after fixes — confirm nothing else broke

**Sweep scope (minimum):**
- Every UI tab/page that was modified or added
- Every API endpoint that was modified or added
- Config-driven features: verify config entries match reality
- Data flow: verify data pipeline from source → processing → display
- Timer/scheduler: verify scheduled items actually fire

**If sweep finds issues:** Loop back to Phase 3 (TDD) with new items. Do NOT skip them.

### Phase 7: DONE CHECK + HANDOFF

- All checklist items checked off?
- All gates pass?
- All sweep issues resolved?

**If yes** → Write the `## Handoff` section in `specs/{slug}.md`, update `**Status:**` to `completed`, commit, push, stop.
**If no** → Loop back to Phase 3 with remaining items.

The `## Handoff` section format:
```markdown
## Handoff

**Completed:** {ISO timestamp}
**Iterations:** {N} of {max}
**Duration:** ~{hours}h
**Commits:** {count}

### Recommendations for Next Agent
1. **Priority fix:** {most impactful remaining issue}
2. **Nice-to-have:** {improvement noticed during sweep}
3. **Tech debt:** {thing that should be refactored but wasn't in scope}
4. **Test gap:** {area that needs more test coverage}

### To resume this work:
\`\`\`bash
cd {repo-path}
git checkout feat/{slug}
# Read: specs/{slug}.md — check Known Issues table and unchecked items
# Run: {command to reproduce any remaining issues}
\`\`\`
```

---

## Loop Discipline

### Max Iterations
- Default: **6 iterations max** (prevents infinite loops while allowing thorough work)
- Override with: `/long-run --max-iterations N {task}`
- Typical: simple features finish in 2-3, complex ones take 4-5, hitting 6 means something's wrong

### Checkpoint (every 2 hours or every 3 iterations, whichever comes first)

Append to the `## Progress Log` section of `specs/{slug}.md`:
```markdown
**{timestamp} — Checkpoint (Iteration {N}/{max}):**
- Done: {completed items summary}
- Remaining: {count} items
- Blockers: {any}
- Status: on-track | behind | blocked
```

### Self-Correction Protocol
1. First failure → diagnose → fix → retry
2. Second failure (same issue) → alternative approach, log what was tried
3. Third failure → mark as blocked, skip to next item, continue loop

### Stop Conditions (hard stops)
- Same failure 3× with no progress on ANY item
- Blocked on auth/secret that can't be found in env or .env
- Destructive operation that needs user confirmation
- Max iterations reached

---

## Git Discipline

- **Branch:** Create `feat/{slug}` from main at start
- **Commits:** After each TDD cycle (test + implementation = 1 commit)
- **Messages:** `feat: {what}`, `test: {what}`, `fix: {what}` — conventional commits
- **Push:** Every checkpoint (every 2h or 3 iterations)
- **Never force-push.** Never rewrite history on a shared branch.

---

## Worktree Setup (optional, for isolation)

For isolation on large changes, run in a git worktree:
```bash
cd {repo}
git worktree add ../{repo}-longrun feat/{slug}
cd ../{repo}-longrun
# open this folder in VS Code, then invoke /long-run
```

For simple features, just branch in the same workspace — worktree is optional.

---

## Integration with Other Skills

| When this happens | Invoke |
|---|---|
| Task unclear, no spec | Phase 1 (GRILL) — decide autonomously |
| Spec exists, ready to build | Phase 3 (TDD) — skip 1 & 2 |
| Spec exists with unchecked items | Resume from first unchecked item |
| Test fails, bug found | Phase 4b (DIAGNOSE) — structured fix |
| Iteration complete | Phase 5 (FLYWHEEL) — learn & clean |
| All checklist items done | Phase 6 (SWEEP) — run app, walk every route |
| Sweep finds issues | Loop back to Phase 3 with new items |
| Gate passes, sweep clean | Phase 7 — write Handoff section, push, stop |

---

## Example Invocations

```
/long-run Split the API monolith into modules
/long-run specs/api-modules.md
/long-run Add rental analyzer module with LLM scoring
/long-run --max-iterations 5 Fix all lint errors in packages/
```

---

## Anti-Patterns

| Don't | Do instead |
|---|---|
| Ask user mid-loop "should I continue?" | Just continue. Stop only on hard-stop conditions. |
| Ask user a question you could answer from codebase/docs | Self-answer with rationale. Only ask when truly stuck after exhausting all sources. |
| Skip failing tests and move on silently | Diagnose up to 3×, then mark blocked explicitly |
| Rewrite the spec mid-loop without logging | Log decision in Progress Log, update spec, continue |
| Commit broken code | Evaluator Gate must pass before commit |
| Run indefinitely | Max 6 iterations + checkpoint timer enforce bounds |
| Over-engineer in Phase 3 | Minimum to pass the test. Refactor is a separate step. |
| Declare "done" without running the app | Verification Sweep is mandatory — run it, click through it |
| Report only successes | Known Issues table must list EVERY problem found, even small ones |
| Skip the Handoff section | Other agents depend on it. Always write it. |
| Say "looks good" without checking each tab/route | Walk every modified route. Log what you see. |
| Create separate -checklist.md, -feedback.md files | Everything goes in ONE `specs/{slug}.md` — single source of truth |
| Skip evaluators because "tests pass" | ALL 6 evaluators must pass. Tests alone don't catch UI bugs or security holes. |
| Run E5/E6 evaluators before E1-E3 | Fast gates first (build/test/lint), expensive gates after (quality/security). |
