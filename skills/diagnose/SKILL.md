---
name: diagnose
description: "Structured debugging loop for hard bugs: feedback loop → reproduce → hypothesize → instrument → fix → regression test. Use when: '/diagnose', 'debug this', 'why is this broken', 'this is failing', 'this throws', 'performance regression', 'flaky test', or any bug that isn't immediately obvious."
---

# Diagnose

A discipline for hard bugs. Skip phases only when explicitly justified.

When exploring the codebase, use the project's domain glossary (`CONTEXT.md`) to get a clear mental model of the relevant modules.

## Phase 1 — Build a Feedback Loop

This is the skill. Everything else is mechanical. If you have a fast, deterministic, agent-runnable pass/fail signal for the bug, you will find the cause. If you don't have one, no amount of staring at code will save you.

**Spend disproportionate effort here. Be aggressive. Be creative. Refuse to give up.**

### Ways to construct one (try in this order):

1. **Failing test** at whatever seam reaches the bug — unit, integration, e2e
2. **HTTP script** (curl/httpx) against a running dev server
3. **CLI invocation** with fixture input, diffing stdout against known-good
4. **Headless browser** (Playwright) — drives UI, asserts on DOM/console/network
5. **Replay captured trace** — save a real request/payload, replay through code path
6. **Throwaway harness** — minimal subset of system exercising the bug path
7. **Property/fuzz loop** — for "sometimes wrong output", run 1000 random inputs
8. **Bisection harness** — automate `git bisect run` between known-good and bad states
9. **Differential loop** — same input through old vs new version, diff outputs

### Iterate on the loop:

- Can I make it faster? (Cache setup, skip unrelated init, narrow scope)
- Can I make the signal sharper? (Assert on the specific symptom, not "didn't crash")
- Can I make it more deterministic? (Pin time, seed RNG, isolate filesystem)

### Non-deterministic bugs:

Loop the trigger 100×, parallelize, add stress, narrow timing windows. A 50%-flake is debuggable; 1% is not — keep raising the rate.

### When you cannot build a loop:

Stop and say so. List what you tried. Ask the user for: (a) access to the reproducing environment, (b) a captured artifact (HAR, log dump, screen recording), or (c) permission to add temporary instrumentation.

**Do not proceed to Phase 2 until you have a loop you believe in.**

## Phase 2 — Reproduce

Run the loop. Watch the bug appear. Confirm:

- The loop produces the failure mode the user described — not a different nearby failure
- The failure is reproducible across multiple runs
- You captured the exact symptom (error message, wrong output, timing)

**Do not proceed until you reproduce.**

## Phase 3 — Hypothesize

Generate **3–5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea.

Each hypothesis must be **falsifiable**:

> Format: "If {X} is the cause, then {action Y} will make the bug disappear / make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen.

Show the ranked list to the user before testing (they often have domain knowledge that re-ranks instantly). Don't block on it — proceed with your ranking if user is AFK.

## Phase 4 — Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:
1. Debugger / REPL inspection (one breakpoint beats ten logs)
2. Targeted logs at boundaries that distinguish hypotheses
3. Never "log everything and grep"

Tag every debug log with a unique prefix: `[DEBUG-xxxx]`. Cleanup = single grep.

**For performance regressions:** logs are usually wrong. Establish baseline measurement (timing harness, profiler, query plan), then bisect. Measure first, fix second.

## Phase 5 — Fix + Regression Test

1. Write the regression test BEFORE the fix (if a correct seam exists)
2. Watch it fail
3. Apply the fix
4. Watch it pass
5. Re-run the Phase 1 feedback loop against the original scenario

**Correct seam** = test exercises the real bug pattern as it occurs at the call site. If no correct seam exists, note it — the codebase architecture is preventing lockdown. Flag for `/flywheel` or architecture review.

## Phase 6 — Cleanup + Post-mortem

Before declaring done:

- [ ] Original repro no longer reproduces (re-run Phase 1 loop)
- [ ] Regression test passes (or absence of seam documented)
- [ ] All `[DEBUG-...]` instrumentation removed
- [ ] Throwaway prototypes deleted
- [ ] Hypothesis that was correct is stated in commit message

Then ask: **what would have prevented this bug?** If the answer involves architectural change, hand off to `/flywheel` with specifics. Make the recommendation after the fix, not before — you have more information now.
