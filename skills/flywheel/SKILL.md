---
name: flywheel
user-invocable: true
description: |
  Continuous improvement loop. Absorb patterns from watchlist repos, optimize any repo.
  Use when: '/flywheel', '/flywheel {repo-path}', 'upgrade copilot', 'copilot self-improvement',
  'flywheel this repo', '飞轮', 'optimize this repo'.
---

# Copilot Flywheel — Continuous Improvement (飞轮效应)

Scout the best repos → absorb into your brain → your brain makes your coding better everywhere.

## Usage

| Command | What happens |
|---------|--------------|
| `/flywheel` | Optimize your copilot config — scout report + apply to instructions/skills/agents/memories |
| `/flywheel {path}` | Optimize a project repo — scan code + fix issues across 6 dimensions |

That's it. Two modes, same command. No sub-commands to remember.

## How it works

```
┌─────────────────────────────────────────────────────────────────┐
│  flywheel_scout worker (automatic, weekly Monday 7am)           │
│  Scans all watchlist repos via GitHub API → LLM analysis        │
│  Writes report to data/flywheel-scout/ + iMessage notification  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  /flywheel (you trigger when ready)                             │
│  1. Check for pending scout report (use it if fresh)            │
│  2. Analyze: what's worth absorbing? what's stale?              │
│  3. Plan: show change table, wait for approval                  │
│  4. Apply: edit files, one logical change at a time             │
│  5. Verify: build/syntax/cross-refs                             │
│  6. Commit + push                                               │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Your copilot config directory (instructions, skills, agents) is git-tracked
- A `flywheel-watchlist.yml` file — tracked repos + stack versions
- `flywheel_scout` worker (generates weekly reports)
- flywheel MCP server (optional — used for `flywheel_scout` tool if available)
- Git, memory tool

---

## Mode 1: `/flywheel` — Optimize Brain

Target: your copilot config (instructions, skills, agents, memories)

### Flow

1. **Gather intel.** Check `data/flywheel-scout/report-*.md` for the latest report. If fresh (< 7 days), use it. Otherwise, run a live scout (flywheel MCP → GitHub API → LLM analysis).

2. **Inventory.** Quick count of instructions/skills/agents/memories. Flag bloat (files > 150 lines, total memory > 500 lines).

3. **Analyze.** Compare scout findings against current state. For each candidate:
   - Already covered? → skip
   - Solves real friction? → keep
   - Worth the token cost? → keep only if applies to 3+ future sessions

4. **Plan.** Show a change table:

   | # | Action | Target | Why |
   |---|--------|--------|-----|
   | 1 | UPDATE | csharp.instructions.md | Add collection expressions pattern |
   | 2 | TRIM | reactjs.instructions.md | 180→95 lines, drop generic rules |
   | 3 | DELETE | stale-agent.md | Never invoked |

   **Wait for approval before editing.**

5. **Apply.** Edit your copilot config. One logical change per write. Stop on failure.

6. **Verify.** Run this checklist — don't skip items:
   - [ ] YAML frontmatter parses on every changed file
   - [ ] Symlinks intact (`ls -la ~/.copilot/` still points into `brain/copilot/`)
   - [ ] applyTo globs match real files (`find ~/code -name '*.cs' | head -3`)
   - [ ] Trigger keywords on modified skills — would Copilot match on phrases you actually use?
   - [ ] Cross-refs resolve — if renamed/moved anything, `grep -r 'old-name' ~/.copilot/` returns empty
   - [ ] Memory writes landed (`memory view /memories/` spot-check)
   - [ ] Git diff shows only intended files (`git diff --stat copilot/`)
   - [ ] Token budget — top-10 instruction line counts didn't balloon

7. **Commit + push.** `chore: flywheel — {one-line summary}`

### Memory cleanup (runs as part of step 2)

- `/memories/*.md`: delete stale entries, trim files > 150 lines
- `/memories/repo/*.md`: delete date-prefixed files older than 14 days
- Don't invent cleanup work. If everything's healthy, say so.

---

## Mode 2: `/flywheel {path}` — Optimize a Repo

Target: any project repo in your workspace

### Flow

Two phases for quality: scan everything in parallel first, then fix one area at a time.

**Phase A — Parallel scan.** Spawn 6 read-only subagents (one per area). Each returns findings + recommendations. Areas:

```
1. structure    — folder layout, README accuracy, build scripts, .gitignore
2. deps         — outdated packages, security advisories, version drift
3. patterns     — code patterns that should be hardened (auth, error handling, config)
4. bugs         — actual defects (data loss, crashes, logic errors)
5. features     — docs/README lagging behind implemented features
6. integration  — cross-repo wiring (mcp.json refs, brain cross-refs, tool names)
```

**Phase B — Serial apply.** For each area in order:
- Triage findings (apply safe high-value items, defer risky ones)
- Edit files
- Build/test
- Commit: `{type}: flywheel [{area}] — {summary}`
- Move to next area

If build fails: stop, show user, ask before continuing.

### Rules for repo flywheel

- Top improvements only — don't rewrite the whole repo
- Match existing architecture and style
- Each area commits independently (easy to revert one without the others)
- Write deferred items in commit body for future runs

---

## Watchlist

Your `flywheel-watchlist.yml` has:

- **Section A (user-managed):** repos you trust and learn from
- **Section B (copilot-managed):** repos discovered by scout, auto-retired when stale
- **Section C (platforms):** where to search for new repos
- **Section D (release feeds):** vendor release notes to scan
- **Stack defaults:** pinned versions for drift detection

The `flywheel_scout` worker reads this file weekly and generates the scout report automatically.

---

## Report

After each run, log the results:

```markdown
# Flywheel — {date} [{target}]

## Changes
| # | Action | Target | Status |
|---|--------|--------|--------|

## Deferred
- {items not applied, with rationale}

## Verification
- Build: {pass/fail}
- Tests: {pass/fail/N/A}
```

---

## Anti-Patterns

- Don't add a pattern just because it looks cool — it must solve friction you actually hit
- Don't restructure multiple things in one run — one structural change max
- Don't skip verification
- Don't edit shared work repos via flywheel (separate review process)

## Relationships

- `flywheel_scout` worker generates the weekly intel automatically
- `flywheel` MCP server provides `flywheel_scout` tool for live scouting
- `/delegate` receives larger items that don't fit a single flywheel run
- Your daily workflow mentions pending scout reports on Mondays
