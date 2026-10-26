---
name: delegate
user-invocable: true
description: |
  Persistent task queue + smart task agent. Six actions:
  1. CAPTURE: User describes work (one line, dump, fuzzy goal, list, URL, or simple reminder). Agent auto-detects shape, plans appropriately, writes to queue/ or Apple Reminders.
  2. DO: PICKUP a queued task by filename, or oldest if no args. Executes and moves to done/.
  3. STATUS / TRIAGE: Show queue state. Surface stale, blocked, deadline-due tasks.
  4. COMPACT: Roll done/ files into monthly summaries.
  5. SCAN: Analyze the current chat and route its content. Four sub-modes auto-detected: COMPACT (one topic, just long → resume file), TRIAGE (one + tangents → park tangents), FAN-OUT (N peer topics → parallel streams), ARCHIVE (end-of-chat permanent record).
  6. REMINDER: Quick-capture to Apple Reminders (no queue file). Auto-detected when input is a simple errand/personal task.
  Use when: "delegate", "capture this", "queue this", "plan this", "split tasks",
  "learn this repo", "pick up task", "what's in the queue", "hand off",
  "todo", "remind me", "don't forget", "add to my list", "note to self", "follow up",
  or you want to record now and execute later.
   SCAN triggers: "/delegate scan", "refocus this chat", "wrap up this chat", "save this chat",
   "close this chat", "this chat is messy", "split this conversation", "park the tangents",
   "get back to A", "compact this chat", "too many topics here", "this chat is too long",
   "let me focus on X", "fan out this chat", "abandon this chat", "everything goes to a new session",
   "what did we talk about in this chat".
---

# Delegate — Task Queue & Parallel Delegation

A file-backed task queue in `delegate/`. Tasks are markdown files that move through folders as they progress. Any agent chat can produce or consume tasks.

## Queue Structure

```
delegate/
├── README.md          # How the queue works (always up to date)
├── queue/             # Tasks waiting to be picked up (FIFO — oldest first)
├── active/            # Currently being worked on (includes blocked tasks)
└── done/              # Completed tasks (compacted monthly)
```

## Task File Format

Every task file uses this structure. The frontmatter is machine-readable; the body is the self-contained prompt.

```yaml
---
title: "{Descriptive task title}"
slug: "{slug}"            # Cross-reference key — matches filename, Apple Reminder body, and log references
created: "{ISO 8601 timestamp}"
deadline: "{YYYY-MM-DD}"    # REQUIRED — every task needs a finish-by date
status: queued          # queued → active → done  (or → blocked from active)
agent: "{suggested agent name or Default Copilot}"
source: "{what session/doc created this task}"
picked_up: null
completed: null
blocked_reason: null    # only set when status is blocked
---
```

**Valid statuses:** `queued` → `active` → `done`. A task can also go `active` → `blocked` (stays in active/). Blocked tasks can resume as `active` or be moved back to `queued`.

**Deadline is mandatory.** Every task must have a `deadline` field. No open-ended tasks — if it doesn't have a deadline, it's not a real commitment.

Below the frontmatter: the full self-contained prompt (context + task + done-when + constraints).

**File naming:** `{YYYY-MM-DD}-{slug}.md` — date first for natural FIFO sort. Slug is lowercase, hyphens, max 50 chars.

Example: `2024-01-15-my-feature.md`

### Slug as Cross-Reference Key

The `slug` field is the canonical link between the task file and its Apple Reminder. Same value appears in three places:

1. **Filename** — `2026-04-10-{slug}.md`
2. **Frontmatter** — `slug: "{slug}"`
3. **Apple Reminder body** — `[delegate:{slug}]`

When searching for a task's reminder (pickup, complete, triage), match on `[delegate:{slug}]` in the reminder body. When searching for a reminder's task file, extract the slug from the body and `find` the matching `.md` file. No fuzzy title matching needed.

---

## ⚠️ Auto-Triage Gate (runs on EVERY invocation)

**Before doing anything else**, scan all folders for issues. This takes 5 seconds and prevents task rot.

1. List all files in `queue/`, `active/`, `done/` (skip `.gitkeep`)
2. Parse frontmatter `created`, `picked_up`, `completed` dates
3. Flag these conditions:

| Condition | Threshold | Action |
|-----------|-----------|--------|
| 🔴 Past deadline | `deadline` < today | Ask user: extend (new date) / finish now / drop |
| Queued task older than 30 days | `created` > 30 days ago | Ask user: keep / drop / re-date |
| Active task with no log entry in 7+ days | Last log timestamp > 7 days ago | Ask user: resume / block / requeue / drop |
| Blocked task | `status: blocked` | Show with `blocked_reason` — ask: resume / requeue / drop |
| Done tasks eligible for compaction | Any done task > 30 days old OR 5+ done files | Suggest `/delegate compact` |
| Duplicate files | Same slug OR same title in multiple folders | Ask user which to keep |

4. If any flags found → show them in a table and ask the user to resolve before proceeding
5. If no flags → proceed silently to the requested mode

**Format:**
```
🔍 Triage check:

| # | Issue | File | Action needed |
|---|-------|------|---------------|
| 1 | Queued 35 days | 2026-02-25-old-task.md | keep / drop / re-date? |
| 2 | Blocked | setup-user-profile.md | "missing source docs" — resume / requeue / drop? |
| 3 | 6 done files, 2 older than 30d | — | Run /delegate compact? |

Reply with actions (e.g. "1: drop, 2: keep, 3: yes") or "skip" to proceed.
```

**Triage actions — what they actually do:**
- **extend** — update `deadline` to a new date (user provides), update the matching Apple Reminder due date
- **finish now** — pick up the task immediately (triggers PICKUP mode)
- **keep** — no change, leave the file where it is
- **drop** — delete the file (confirm with user first)
- **re-date** — update `created` to today, leave in queue/
- **resume** — flip `status` back to `active`, clear `blocked_reason`. Does NOT start executing — user picks it up separately via PICKUP
- **requeue** — move file from active/ to queue/, set `status: queued`, clear `picked_up` and `blocked_reason`
- **block** — set `status: blocked`, prompt for `blocked_reason`
- **compact** — run Action 5: COMPACT

---

## Routing

After auto-triage resolves (or no issues found), pick the action:

| Input | Action |
|-------|--------|
| `/delegate` (no args, queue/ has files) | **DO** — pick up the oldest queued task |
| `/delegate` (no args, queue/ empty) | **STATUS** |
| `/delegate {filename}` (matches a file in queue/ or active/) | **DO** — pick up / resume that task |
| `/delegate status` / `triage` / `compact` | housekeeping |
| `/delegate scan` (or any chat-scoped SCAN trigger phrase from frontmatter) | **SCAN** — analyze current chat, auto-detect mode, route content |
| `/delegate {anything else}` | **CAPTURE** — agent reads the input, auto-detects shape, plans, writes to queue/ |

**Filename vs description:** if the input matches an existing `.md` filename in `queue/` or `active/` (with or without extension, with or without date prefix), it's DO. Otherwise CAPTURE.

**Override hints inside Capture:** the user can force a specific shape inline. The agent honors these:
- "just queue it" / "skip planning" → **quick** path
- "design it first" / "make a plan" → **plan** path
- "split this up" / "there's multiple things here" → **dump** path
- "treat as one task" → **single** path

### When to use VS Code built-ins instead

VS Code 1.105+ ships `/compact` and `/fork` chat commands. They overlap with delegate scan but serve different purposes — pick the right tool:

| You want to... | Use |
|---|---|
| Trim chat history while staying in same session (free up context) | VS Code built-in `/compact` (optionally with focus hint) |
| Spawn a new chat inheriting current history (branch the conversation) | VS Code built-in `/fork` |
| Save chat content to a persistent file in `delegate/done/` for later reference | `/delegate scan` ARCHIVE |
| Park tangents to separate queue files while continuing main thread | `/delegate scan` TRIAGE |
| Split N peer topics into N parallel queue files | `/delegate scan` FAN-OUT |
| Compact a long single-topic chat into a resume file (separate session pickup) | `/delegate scan` COMPACT |

Rule of thumb: built-ins handle in-session context; `/delegate scan` produces persistent artifacts.

---

## Action 1: CAPTURE — Smart Task Creation

**Trigger:** Anything other than a filename, `status`, `triage`, or `compact`.

The agent reads the input, detects its shape, runs the right workflow, and writes to the queue. **Don't ask the user which mode** — pick based on what they actually said.

### Step 1: Detect Input Shape

Classify the input into one of five shapes. If genuinely ambiguous, ask **one** question.

| Shape | Looks like | Workflow |
|-------|-----------|----------|
| **reminder** | Simple errand, personal task, "buy X", "call Y", "don't forget Z" — not agent-actionable work | Create Apple Reminder directly (no queue file), auto-route to correct list |
| **single-quick** | One short line, no design needed. "fix lint in auth.ts" | Skip planning, write task, 14-day default deadline |
| **single-plan** | One fuzzy goal that needs design. "migrate Flask to FastAPI", "refactor the auth flow" | Discovery → Alignment → Design → write plan-task |
| **list** | A clean numbered/bulleted list of 2+ related tasks the user already organized | One file per item, standard context gathering |
| **dump** | Multi-paragraph or stream-of-consciousness with mixed topics | Parse into N tasks, classify each item, show table, confirm |
| **url-learn** | Input is a URL (GitHub repo, blog post, doc page) | Treat as a "learn this resource" task — see Step 2c |

**Override hints:** if the user said "just queue it", "design it first", "split this up", or "treat as one task", honor that and skip detection.

### Step 2: Run the Right Workflow

#### 2a. single-quick

1. One-line title from the input.
2. Auto-fill: `agent: "Default Copilot"`, `deadline: today + 14 days`, `plan_depth: quick`.
3. Skip Discovery and Alignment.
4. Show 1-line summary, ask `y / change deadline / cancel`.
5. On **y**, write the file (Step 3) + create reminder (Step 4) + show summary (Step 5).

Task body:

```markdown
## Task
- [ ] {user's text, lightly cleaned}

## Done When
- [ ] User-specified outcome achieved
```

#### 2b. single-plan

Spend the design time now so PICKUP is pure execution.

1. **Discovery (read-only).** Use the Explore subagent for codebase scans. Gather:
   - Codebase reality — relevant files, existing patterns, related tests, current behavior. Read the actual files.
   - Constraints — instructions/skills that apply, repo conventions in `.github/copilot-instructions.md`, related memory entries.
   - Risk surface — what depends on this code? What breaks if it changes?
   - Prior art — git log for similar past changes, related queue/done tasks.

   Output: a Discovery summary (3–8 bullets) — facts only, no design yet.

2. **Alignment.** Surface the decisions the user needs to make. Ask **2–5 specific questions** with concrete options and a recommended default. Wait for answers.

3. **Design.** Write the plan as numbered phases with concrete checkbox steps:

   ```
   Phase 1: Scaffolding (no behavior change)
     - [ ] 1.1 ...
     - [ ] 1.2 ...
   Phase 2: ...
   Phase 3: Cutover
   Phase 4: Cleanup
   ```

   Each step small enough to verify done. Include verification steps explicitly.

4. **Confirm + write.** Show:

   ```
   Plan ready: {title}
   Discovery: {one-line summary}
   Decisions: {one-line summary}
   Phases: {N}, steps: {total}
   Suggested deadline: {date based on scope}
   Reply: y / change deadline / edit plan
   ```

   On **y**, write the file (Step 3) with `plan_depth: full` + Discovery / Decisions / Plan / Verification sections + create reminder + show summary.

#### 2c. url-learn

Input is a URL — the user wants to learn from this resource and capture takeaways.

1. **Detect type:** GitHub repo, blog post / article, documentation page, video, other.
2. **Quick scan** (read-only, don't deep-clone):
   - GitHub repo → `fetch_webpage` README + recent commits + repo description; note language, star count, last commit date
   - Article / docs → `fetch_webpage` for title + 1-paragraph summary
   - Other → minimal fetch, infer purpose from URL + title
3. **Propose the learning task** with concrete extraction steps:

   ```markdown
   ## Task
   - [ ] Read README and architecture docs
   - [ ] Identify {N} key patterns / techniques
   - [ ] Find concrete examples of each
   - [ ] Compare with existing patterns in your repos / instructions
   - [ ] Write takeaways to /memories/ or to relevant instruction file
   - [ ] Decide flywheel fate (asked at completion): watch + clone / watch-only / drop
   ```

4. Auto-fill: `agent: "Explore"` (for codebases) or `"Default Copilot"`, `deadline: today + 21 days`, `plan_depth: quick`.
5. Show 1-line summary + the URL + proposed extraction steps, ask `y / edit / cancel`.
6. On **y**, write file + reminder + summary.

Slug rule: derive from URL path. `https://github.com/forrestchang/andrej-karpathy-skills` → `learn-andrej-karpathy-skills`.

#### 2f. reminder

Input is a simple personal errand or "don't forget" — NOT agent-actionable work. No queue file needed.

1. **Route to the correct Apple Reminders list** based on content signals:

   | Signal | List |
   |--------|------|
   | Errand, "buy X", personal task | Personal |
   | Work task, "follow up AB#XXXX", meeting prep | Work |
   | "learn X", "check out Y", tech to explore, GitHub/HF URLs | ToLearn |
   | Investment, finance, stock | Investment |
   | Tax, receipt, filing | Tax |
   | Household, utilities | Home |
   | Family, personal | Family |
   | Travel, trip planning | Travel |
   | Unclear | Inbox |

2. **Extract**: title (short), due date (if mentioned, else none), notes (context/URL if relevant).
3. **Create immediately** via osascript — no confirmation needed for simple reminders:

   ```bash
   osascript -e 'tell application "Reminders"
     tell list "{LIST}"
       make new reminder with properties {name:"{TITLE}", body:"{NOTES}"}
     end tell
   end tell'
   ```

   With due date: add `due date:d` where `d` is `date "March 25, 2026"` (AppleScript locale format).

4. **Confirm**: `✅ Added to {list}. Will show up in your next daily triage.`

5. **Learning fast-track**: When item routes to `ToLearn` and the current chat has relevant context, offer:
   ```
   💡 Context is fresh. Want me to create a delegate task with a spike plan? (y/n)
   ```
   On **y**, escalate to `url-learn` or `single-plan` shape.

#### 2d. list

Input is already organized as a clean multi-item list.

1. **Parse.** Extract individual items, group logically (don't split what belongs together), detect dependencies (B needs A's output → same stream).
2. **Gather context per item** (run `ls`, read referenced files — don't guess).
3. **Pick agent per item:**

   | Task type | Suggested agent |
   |-----------|----------------|
   | Family profile / document org | Default (Copilot) |
   | Code review / PR | pr-reviewer via skill |
   | .NET / C# code | C#/.NET Janitor or default |
   | React / frontend | Expert React Frontend Engineer |
   | Database / SQL | MS-SQL Database Administrator |
   | Azure infra | Azure Principal Architect |
   | Security review | SE: Security |
   | Domain-specific tasks | Relevant domain agent |
   | General research | Explore agent |
   | Learning a repo / article | Explore or Default |

4. **Show plan, confirm:**

   ```
   Plan — {N} tasks:

   | # | Slug | Agent | Title | 1-line summary |
   |---|------|-------|-------|----------------|

   ⏰ Deadline?
     → "y" = 30 days from today
     → "y, 14 days" = uniform deadline
     → per-task: "1: 7 days, 2: 2 weeks"
   ```

5. On **y**, write all files + create one reminder per task + show summary.

#### 2e. dump

Stream-of-consciousness with multiple things mixed in.

1. **Parse.** Identify distinct tasks (different goals, different domains, different agents). One sentence ≠ one task — group related sentences. Discard pure venting / emotional context.
2. **Classify each item** with the shape detector from Step 1 — some items become single-quick, some single-plan, some url-learn.
3. **Show the parsed plan** as a table with each item's classification:

   ```
   Parsed your dump into {N} tasks:

   | # | Slug | Shape | Agent | Title |
   |---|------|-------|-------|-------|
   | 1 | fix-alert-null-ref | single-quick | Default | Fix alert null-ref bug |
   | 2 | rotate-aws-keys | single-quick | Default | Rotate AWS keys |
   | 3 | design-export-csv | single-plan | code-perfectionist | Design export-to-CSV (will plan on pickup) |
   | 4 | learn-andrej-karpathy | url-learn | Explore | Learn karpathy skills repo |

   y / edit / drop {#}?
   ```

4. For items classified as single-plan, **don't run Discovery/Alignment now** — write a stub task with `plan_depth: standard` and a note: "Run `/delegate plan` on this when ready to start." This keeps the dump-capture fast.
5. For single-quick and url-learn items, generate full task content immediately.
6. On **y**, write all files + reminders + summary.

### Step 3: Write the Task File

Common file format for every shape. Path: `delegate/queue/{YYYY-MM-DD}-{slug}.md`.

**Before writing:** check for filename collisions in queue/, active/, done/. If collision, append `-2`, `-3` to the slug.

```markdown
---
title: "{Title}"
slug: "{slug}"
created: "{ISO 8601 — current time}"
deadline: "{YYYY-MM-DD}"
status: queued
plan_depth: quick      # quick | standard | full
agent: "{agent name}"
source: "{brief description of the creating session}"
picked_up: null
completed: null
blocked_reason: null
---

# {Title}

## Context
{Self-contained — file paths from `ls`, naming conventions, what's done, relevant skill/instruction refs. Include URL + first-glance summary for url-learn shape.}

## Task
**Every step is a checkbox.** Small, concrete, agent-verifiable.
- [ ] Step 1: {action}
- [ ] Step 2: {action}

## Done When
**Acceptance criteria as checkboxes.**
- [ ] {criterion}

## Don't
{Scope guards — files not to touch, things not to change.}

## Log
<!-- Agent appends progress entries here -->
```

For `plan_depth: full`, also include `## Discovery`, `## Decisions`, and `## Plan` (with phases) sections — see 2b.

**Self-contained means self-contained.** A fresh agent with zero prior context can execute by reading just this file.

### Optional: route DO action to Copilot CLI worktree

When picking up a task, you can run it inside a **Copilot CLI worktree session** instead of the current chat. Worktree sessions:

- Auto-bypass approval prompts (run unattended)
- Get an isolated git worktree under `.copilot/worktrees/` — no contamination of your current branch
- Stream into the Sessions view so you can monitor without context-switching
- Are ideal for: well-scoped tasks, parallel variant exploration ("try 3 approaches in parallel"), long-running scaffolds, repo-learn tasks

**Route to CLI worktree when:**
- The task has a clear definition of done (acceptance checkboxes filled in)
- You don't need to iterate live with the agent
- You want it running in the background while you do other work
- You want to fan out 2-3 variants of the same task and compare results

**Don't route to CLI worktree when:**
- The task is exploratory and you want live steering
- The task touches the working tree of the current branch (worktree is a separate copy)
- The task needs interactive credentials or human decisions mid-flight

**How to launch:** Command Palette → `Chat: New Copilot CLI` → paste the task body. Select the latest top-tier model in the CLI/model picker before starting. Monitor in Sessions view (`workbench.startupEditor: agentSessionsWelcomePage`).

**Parallel variants pattern:** for high-stakes tasks, launch 3 CLI worktree sessions with the same task body but different prompts ("approach A: refactor", "approach B: rewrite", "approach C: minimal patch"). Compare diffs. Merge the winner. Discard the others.

### Step 4: Create Apple Reminder

For each task created, add an Apple Reminder so the deadline shows up in your daily workflow.

**List routing** (same as `/todo`):
| Task type | Reminders List |
|-----------|---------------|
| Work task | Work |
| Personal project, learning, coding | Personal |
| Property-related | Property |
| Finance/tax | Investment or Tax list |
| Default | Personal |

```bash
osascript -e 'tell application "Reminders"
  tell list "{LIST}"
    set d to date "{Month Day, Year}"
    make new reminder with properties {name:"[delegate] {title}", body:"[delegate:{slug}] delegate/queue/{filename}", due date:d}
  end tell
end tell'
```

- **Name:** `[delegate] {title}`
- **Body:** `[delegate:{slug}] {path}` — the slug tag is the canonical link
- If a reminder with this slug already exists (e.g. from `/todo` escalated): update the due date, don't duplicate.

### Step 5: Show Summary

```
Queue updated — {N} task(s) created:

| # | File | Shape | Agent | Title |
|---|------|-------|-------|-------|

Pick up: open a new chat (Cmd+Shift+I) →
  /delegate {filename}     ← specific task
  /delegate                ← oldest queued

Continuing in this chat: {what stays here, or "nothing — all queued"}
```

---

## Action 2: DO (PICKUP) — Execute a Queued Task

**Trigger:** One of these:
- `/delegate {filename}` — pick up a specific task
- `/delegate` with no task description, when `delegate/queue/` has files — pick up the oldest

### Step 1: Find the Task

- If filename given → look in `queue/` first, then `active/` (for resuming blocked/stale tasks)
- If no filename → list `delegate/queue/`, sort by filename (date prefix = FIFO), pick the first one
- If found in `active/` → this is a **resume** (skip Step 2 — file is already claimed). Go to Step 2b.
- If queue is empty → show "Queue empty. Nothing to pick up." and list any `active/` tasks

### Step 2: Claim the Task

**Update the file FIRST, then move it.** This way the file is self-documenting even if the move fails.

1. Read the file from `queue/`
2. Update frontmatter in place: `status: active`, `picked_up: "{current ISO 8601 timestamp}"`
3. Append to Log section: `- {timestamp}: Picked up by agent`
4. Move it: `mv delegate/queue/{file} delegate/active/{file}`
5. **Verify the move:** Run `ls delegate/active/{file}` — confirm it exists. Run `ls delegate/queue/{file}` — confirm it's gone. If verification fails, stop and tell the user.
6. **Close the CAPTURE stage:** Search ALL Apple Reminders lists for the matching reminder by slug tag in body. If found, mark it as completed — the delegate task file now owns this work.
   ```applescript
   tell application "Reminders"
       set allLists to every list
       repeat with l in allLists
           set matchingReminders to (every reminder of l whose body contains "[delegate:{slug}]" and completed is false)
           repeat with r in matchingReminders
               set completed of r to true
           end repeat
       end repeat
   end tell
   ```
   Fallback: if no body match, search by `name contains "{keyword}"` for older reminders without the slug tag.
7. Tell the user: "Picked up **{title}**. Moved to `active/`. Matching reminder(s) marked done."

### Step 2b: Resume a Task (from active/)

When the file is already in `active/` (blocked or stale from a dead chat):

1. Read the file — check the Log section for what was already done
2. If `status: blocked` → update frontmatter: `status: active`, `blocked_reason: null`
3. Append to Log: `- {timestamp}: Resumed by agent (was blocked: {old reason})`
4. Tell the user: "Resuming **{title}** — picking up from last log entry. Previous progress preserved."
5. Proceed to Step 3

### Step 3: Execute the Task

**Before starting:** Read `delegate/learnings.md`. If it has entries, scan for anything relevant to this task's domain and inject useful learnings as context. If the file is empty, skip.

**Preflight coupled actions:** Call `brain_preflight` with the task description. Note which coupled actions apply (hard and soft). These must be satisfied before Step 5 (Complete).

Read the Task section and execute it step by step. Treat it exactly like a user request.

**Checkbox discipline — this is mandatory:**
1. Work through the Task checkboxes **in order**, top to bottom
2. After completing each step, **update the file** — change `- [ ]` to `- [x]` for that step
3. If a step can't be completed, **don't skip it** — either block the task (Step 4) or ask the user
4. Before moving to Step 5 (Complete), verify **every checkbox** in both Task and Done When sections is checked. If any `- [ ]` remains, the task is not done.
5. If you're resuming a task, read the checkboxes first — anything already `- [x]` was done by the previous agent session. Start from the first unchecked `- [ ]`.

As you work, **append progress to the Log section** in the active file:
- `- {timestamp}: ✅ Step 1 — {description}`
- `- {timestamp}: ✅ Step 3 — {what was done}`
- `- {timestamp}: ❌ Blocked on step 4 — {issue}`

### Step 4: Block (when stuck)

If the agent hits a wall that needs external action, or the user says "block this" / "pause this":

1. Update frontmatter: `status: blocked`, `blocked_reason: "{why it's stuck — be specific}"`
2. Append to Log: `- {timestamp}: BLOCKED — {reason}. Progress saved above.`
3. File **stays in active/** — it has partial work that would be lost if requeued
4. Tell the user: "Blocked **{title}** — {reason}. It'll show up in triage next time you run /delegate."

**The user can also block manually mid-conversation** by saying "block" or "pause." Same steps apply.

### Step 5: Complete

When all "Done When" criteria are met:

**Pre-flight check:** Scan the task file for any remaining `- [ ]` (unchecked boxes). If ANY exist in the Task or Done When sections, the task is NOT complete — go back and finish them or explicitly note why they were skipped.

**Coupled-action gate:** Call `brain_verify_completion` with the task description and a list of actions taken during execution. If any **hard** coupled actions are missing, go back and complete them before proceeding. If only **soft** actions are missing, warn the user but allow completion.

**⚠️ MANDATORY: Ask the user to confirm before completing.** The agent NEVER moves a task to done/ on its own. Show the completion summary and ask "Mark this done?" — only proceed if the user explicitly says yes/done/ship it.

**Update the file FIRST, then move it.**

1. Write a **completion summary** in the Log section (required — not optional):
   ```
   - {timestamp}: ✅ COMPLETED
     - What was done: {2-5 bullet points of what was accomplished}
     - Files created/changed: {list of paths}
     - Gotchas: {anything the user should know, or "none"}
   ```
2. **Extract learnings:** If the task produced reusable insights (gotchas, patterns, shortcuts), append them to `delegate/learnings.md`:
   ```
   - {date} [{task-slug}]: {one-line learning}
   ```
   Skip if nothing non-obvious was learned.
3. **If task was `url-learn` shape:** ask the **flywheel fate question** explicitly before writing the log row:

   > "Flywheel fate for {repo}? **[w]atch + clone** / **[o]watch-only (URL scan)** / **[d]rop**"

   Recommend a default based on what was learned:
   - **watch + clone** if patterns keep coming up, you'll consult it again, or it's actively evolving (commits in last 30 days)
   - **watch-only** if it's worth periodic re-scans but you won't grep it (e.g. personal indie repo, small surface area)
   - **drop** if you extracted what you needed and there's nothing more to learn (most one-off reads)

   Then act on the choice:
   - **watch + clone**: `git clone --depth=50 {url} playground/_watchlist/{repo-name}`, add entry to `flywheel-watchlist.yml` `user_managed:` with `local_clone:` path, set log status to `absorbed + watching`
   - **watch-only**: add entry to `flywheel-watchlist.yml` `user_managed:` without `local_clone:`, set log status to `absorbed + watching`
   - **drop**: no watchlist change, set log status to `absorbed`, append `dropped from watch: {1-line reason}` to the log's Notes column

   Then append the row to your learning log at the top of the current-year table:
   ```
   | {YYYY-MM-DD} | [{repo or article name}]({url}) | repo/article/docs | {status} | [task]({path-to-done-file}) | [TIL]({path-to-cheatsheet-if-any}) | {1-line takeaway}{; dropped reason if applicable} |
   ```
   If you wrote a TIL during the task, link it. If not, leave the TIL cell as `—`.
4. Show the completion summary to the user and **ask for confirmation**: "Mark this done?"
5. **Wait for explicit user approval.** If the user says no, wants changes, or asks questions — address those first. Loop back to Step 3 (Execute) and continue working.
6. Update frontmatter: `status: done`, `completed: "{current ISO 8601 timestamp}"`
7. Move file: `mv delegate/active/{file} delegate/done/{file}`
8. **Verify the move:** `ls` both paths — confirm file exists at destination, gone from source. If the destination already has a file with the same name, append `-2` to the slug before moving.
9. **Mark the paired Apple Reminder as completed.** Search all Reminders lists by slug tag in body:
   ```applescript
   tell application "Reminders"
       set allLists to every list
       repeat with l in allLists
           set matchingReminders to (every reminder of l whose body contains "[delegate:{slug}]" and completed is false)
           repeat with r in matchingReminders
               set completed of r to true
           end repeat
       end repeat
   end tell
   ```
   Fallback: if no body match, search by `name contains "{keyword}"` for older reminders.
   If no matching reminder found, warn: "No matching Apple Reminder found — check manually."

### Handling Failures

- If the agent chat dies mid-task → file stays in `active/` with `status: active`. The Log shows what was done.
- Next `/delegate` invocation: auto-triage catches it (no log entry in 7+ days) and asks user what to do.
- To resume: open a new chat, `/delegate {filename}` — agent reads the Log and continues where it left off.
- The Log section preserves all progress so the next agent doesn't repeat work.

---

## Action 3: STATUS — Show Queue State

**Trigger:** `/delegate status` or `/delegate` when user seems to be asking about state.

List all tasks across all folders:

```
Task Queue:

QUEUED ({N}):
| # | File | Created | Age | Agent | Title |
|---|------|---------|-----|-------|-------|

ACTIVE ({N}):
| # | File | Picked Up | Age | Agent | Title |
|---|------|-----------|-----|-------|-------|

BLOCKED ({N}):
| # | File | Reason | Age | Title |
|---|------|--------|-----|-------|

DONE ({N}):
| # | File | Completed | Title |
|---|------|-----------|-------|
```

Blocked tasks are pulled from active/ where `status: blocked`. Show them separately so they stand out.

---

## Action 4: TRIAGE — Deep Queue Review

**Trigger:** `/delegate triage` or auto-triggered when the auto-triage gate finds issues.

This is an interactive cleanup session. For each issue found:

1. Show the issue and the file's last few log entries for context
2. Offer actions:
   - **Queued (stale):** keep / drop / re-date (update `created` to today)
   - **Active (stale):** resume now / block (with reason) / requeue / drop
   - **Blocked:** resume now / requeue / drop
   - **Done (old):** compact / keep / delete
   - **Duplicate:** pick which copy to keep, delete the other
3. Execute the chosen action immediately
4. Move to next issue

After all issues resolved, show the clean STATUS view.

---

## Action 5: COMPACT — Summarize Done Tasks

**Trigger:** `/delegate compact` or suggested by triage when done/ has 5+ files or files older than 30 days.

### Step 1: Read All Done Files

Skip any existing summary files (`*-completed-summary.md`). For each individual task file in `done/`, extract:
- Title, created date, completed date, agent
- The completion summary from the Log section (the ✅ COMPLETED block)
- If no completion summary exists, extract the last 3 log entries as a fallback

### Step 2: Group by Month

Group tasks by their `completed` month (YYYY-MM).

### Step 3: Write Summary File(s)

For each month, create `done/{YYYY-MM}-completed-summary.md`:

```markdown
---
type: monthly-summary
month: "{YYYY-MM}"
compacted: "{ISO 8601 — now}"
task_count: {N}
---

# Completed Tasks — {Month Year}

| # | Task | Completed | Agent | Summary |
|---|------|-----------|-------|---------|
| 1 | {title} | {date} | {agent} | {1-2 line summary from log} |
| 2 | {title} | {date} | {agent} | {1-2 line summary from log} |

## Details

### {Title 1}
- Completed: {date}
- Files changed: {list}
- Notes: {gotchas or key decisions}

### {Title 2}
...
```

### Step 4: Confirm & Delete

Show the summary to the user. List which individual files will be deleted.

```
Compacted {N} tasks into {filename}:
{summary table}

Will delete these individual files:
- done/2026-03-31-task-a.md
- done/2026-03-31-task-b.md

Confirm? (y/n)
```

Only delete after user confirms with **y**.


## Action 6: SCAN — Analyze Current Chat & Route Content

**Trigger:** `/delegate scan`, `refocus this chat`, `wrap up this chat`, `save this chat`, `close this chat`, `messy chat`, `split this conversation`, `back to A`, `compact this chat`, `fan out this chat`, `abandon this chat`, `what did we talk about in this chat`.

A meta-action that analyzes the **current chat** and routes its content to the right home. Picks one of four sub-modes based on chat shape (or asks if ambiguous).

### Mode auto-detection

| Signal | Mode |
|---|---|
| User says "wrap up this chat", "save this chat", "close this chat", "what did we talk about in this chat" | **ARCHIVE** (end-of-chat permanent record) |
| ≥ 80% of recent messages on same primary topic; chat is just long | **COMPACT** (resume file for new chat) |
| One clear primary + 1-3 tangents the user wants to defer | **TRIAGE** (park tangents) |
| 2+ peer topics, user wants to work on them concurrently | **FAN-OUT** (parallel streams) |

If ambiguous, ask the user once. Never silently pick the wrong mode.

### Sub-mode 1: COMPACT (one topic, conversation got long)

**For:** resume the same topic in a fresh chat with full state preserved.

1. Identify the single topic and current state (Done / In progress / Blocked).
2. Write `/memories/repo/{YYYY-MM-DD}-{slug}.md` using the standard session format:
   - Context / Done / Current State / Next / Notes / Cleanup
   - The `## Cleanup` section reminds future agent to delete the file when work is done.
3. Suggest `/fork` from the last clean message (or starting a new chat).
4. Output a one-line bootstrap prompt:
   ```
   Continuing work on {topic}. Read /memories/repo/{date}-{slug}.md for state.
   Next step: {one specific action}
   ```

**Why repo memory, not session memory:** session scope is per-chat (new chat can't see it). Repo scope is workspace-bounded and auto-listed in every chat's `<repoMemory>` block.

### Sub-mode 2: TRIAGE (one main topic + N tangents)

**For:** stay in this chat, get back to focus, park tangents.

1. Identify the **primary topic** (what the user said first or explicitly wants to refocus on).
2. List the **tangents** — anything off-topic that came up.
3. For each tangent, draft a self-contained delegate task (title, body, suggested agent, deadline).
4. Show the user the list, ask: "Capture all? Or pick which to keep / drop / merge?"
5. On confirmation, hand off to **CAPTURE** for each approved tangent.
6. Output a **scope-reset message** for the user to paste:
   ```
   Refocusing. Primary scope: {topic}. Parked to delegate: {list of slugs}.
   Ignore prior tangent discussion — those are queued separately.
   ```

### Sub-mode 3: FAN-OUT (multiple peer topics, want parallelism)

**For:** split N independent topics into parallel streams.

**Two variants — ASK which one:**
- **3a. Keep-one-here:** N-1 topics fan out, 1 stays in this chat (the most interactive). Default for medium complexity.
- **3b. Pure fan-out:** ALL N topics get fresh sessions; current chat is abandoned. Pick when (a) every topic deserves clean context, (b) current chat is polluted, (c) user says "everything goes to a new session" or "abandon this chat."

**Steps:**
1. List the N peer topics.
2. For each, draft a delegate task with **full self-contained context** (no "see earlier in this chat" — extract everything). Fresh agent must pick it up cold.
3. Ask: "Approve all N? Variant 3a (keep one here) or 3b (pure fan-out)?"
4. On confirmation, hand off to **CAPTURE** for each.
5. Output a launch plan. Two formats:

   **Variant 3a (keep-one-here):**
   ```
   Stream 1 (main chat, here): {slug-1}
   Stream 2 (CLI worktree):    {slug-2}  → Cmd+Shift+P → Chat: New Copilot CLI
   Stream 3 (CLI worktree):    {slug-3}  → Cmd+Shift+P → Chat: New Copilot CLI
   ```

   **Variant 3b (pure fan-out):**
   ```
   This chat will be abandoned. Launch all N streams in fresh sessions.

   Stream 1 (new VS Code chat):  {slug-1}
     → Cmd+Shift+P → Chat: New Chat
     → Paste: /delegate do {slug-1}
   Stream 2 (CLI worktree):      {slug-2}
     → Cmd+Shift+P → Chat: New Copilot CLI
     → Paste: /delegate do {slug-2}
   Stream 3 (new VS Code chat):  {slug-3}
     → Cmd+Shift+P → Chat: New Chat
     → Paste: /delegate do {slug-3}

   When all streams launched: close this chat (Ctrl+W on the chat tab).
   ```

### Sub-mode 4: ARCHIVE (end-of-chat permanent record)

**For:** chat is done, capture topics + decisions + open items as a permanent searchable record.

1. Scan the full conversation. Extract:
   - **Topics** — distinct subjects (group related exchanges under one topic)
   - **Decisions** — anything decided or concluded
   - **Open items** — things unfinished or worth continuing
   - **Key learnings** — non-obvious insights worth remembering
2. Pick title slug. Format: `{YYYY-MM-DD}-{slug}.md` (kebab-case main theme).
3. Show draft, ask `y / edit / cancel`.
4. On **y**, write to `chat-summaries/{date}-{slug}.md`:

   ```markdown
   # Chat Summary: {Title}

   **Date:** {start-date} to {end-date}
   **Status:** Closed — start new chats per topic below

   ---

   ## Topics Covered

   ### 1. {Topic Title}
   - {Key point}
   - {Decision or outcome}

   ---

   ## Open Items

   > **{Item 1}** — {context of where you left off}

   ---

   ## Decisions Made

   - {Decision 1}: {rationale}
   ```

5. **Open items routing:** for each open item, ask "queue as delegate task?" If yes, hand off to **CAPTURE**.
6. **Memory check:** if any topic produced a reusable insight (preference, pattern, gotcha), offer: "One insight worth saving to `/memories/`: {description}. Add it?"

### SCAN — Don't

- Don't summarize and dump back into the same chat — that adds tokens, doesn't save them. The whole point is to **leave the chat** with state preserved elsewhere.
- Don't auto-fire `/fork` — VS Code's fork is a UI action; just *suggest* the user click Fork on a specific message.
- Don't write COMPACT resume files to `/memories/session/` — per-chat scope; new chat can't read it.
- Don't write to `/memories/` (global) — chat state is workspace-bounded, not a universal preference.
- Don't capture trivial single-line tangents — collapse them into the scope-reset message.
- Don't auto-save ARCHIVE without showing the draft first.

### SCAN — Done When

- [ ] Mode chosen (COMPACT / TRIAGE / FAN-OUT / ARCHIVE) and confirmed if ambiguous
- [ ] All non-primary content has a home (resume file / delegate tasks / archive file)
- [ ] User has a copy-pasteable next-step (bootstrap prompt, scope-reset message, launch plan, or archive confirmation)
- [ ] Nothing silently dropped — every tangent / open item is captured, merged, or explicitly skipped

---

## Rules

- **Read files, don't assume.** Run `ls`, read docs, check Apple Notes — get the actual current state.
- **Each task file must be 100% self-contained.** A fresh chat with zero prior context must be able to execute it by reading just that file. Pack in file paths, naming conventions, what's already done, acceptance criteria.
- **Update frontmatter BEFORE moving files.** The file must be self-documenting regardless of which folder it's in. If the move fails or the chat dies, the frontmatter still reflects the true state.
- **Verify every move.** After `mv`, run `ls` on both source and destination. If the file didn't move correctly, stop and tell the user.
- **Check for filename collisions** before moving. If destination already has a file with the same name, append `-2`, `-3`, etc.
- **Include naming conventions in every family-related task.** People mess this up without the reference.
- **Don't include irrelevant context.** A task about organizing PDFs doesn't need the CORS config.
- **Always list what stays in this chat** (capture flow). The user needs to know what they're continuing with.
- **If tasks aren't independent, say so.** Don't fake parallelism when there's a dependency chain.
- **Deduplicate identical subtasks.** If 4 family members need the same workflow, consider one task with a loop.
- **Include a known-good example file as reference** when delegating similar-shaped tasks.
- **Never delete files without user confirmation.** Moves are fine, deletes always need a "y."
- **Completion summaries are mandatory.** Every task moved to done/ must have a ✅ COMPLETED block in the Log. No empty completions.
- **One file per task, one folder at a time.** A task file should never exist in two folders simultaneously. If you find duplicates, triage catches it.

## Queue Maintenance

- `done/` files are compacted monthly via `/delegate compact`. Individual files are deleted after compaction.
- If a file sits in `active/` but no agent is working on it → auto-triage flags it after 7 days with no log entry.
- Blocked tasks stay in `active/` with `status: blocked` — they have partial work that shouldn't be lost.
- `delegate/` is git-tracked. Commit the queue state if you want history.

---

## Subagent Mode (per-task fresh-context execution)

**Per zero-skip rule:** the DO action benefits massively from a fresh subagent context per task. Keeps each pickup isolated, prevents cross-task contamination, and lets the orchestrator track multiple tasks without burning main-context tokens.

### When to fan out
- **DO action with batch pickup** ("do top 3") — spawn one subagent per task in parallel where tasks are independent, sequential where they share files.
- **DO action single task** — still spawn a subagent if the task involves heavy file reading (url-learn, repo-learn, multi-file refactor). Keeps main context clean.
- CAPTURE / STATUS / COMPACT — inline, no fan-out.

### Fan-out unit
One subagent per **task file**. Independence determined by file scope declared in the task frontmatter.

### Orchestrator workflow
1. Pick task(s) from `queue/`. Move each to `active/`.
2. Initialize todo list with one item per task.
3. Spawn subagent per task. Pass: task file path, scope, deadline.
4. Each subagent executes the task end-to-end and writes its own outputs (learning notes, code edits, reports).
5. As each returns: verify output files exist, move task to `done/{YYYY-MM-DD}/`, log outcome.
6. On failure: leave in `active/` with `status: blocked` + log entry.

### Per-subagent prompt skeleton

```
You are executing ONE delegate task end-to-end.

Task file: {path}
Scope (from frontmatter): {scope}
Deadline: {deadline or none}

Read the task file fully, execute the work, write any outputs to the paths declared in the task.
Apply: zero-skip, think-deeper, all repo conventions for the target workspace.

Report in this exact format:
  STATUS: success | partial | failed | blocked
  TASK: {filename}
  WORK DONE: <bullets>
  OUTPUTS: <files created/modified, commits if any>
  BLOCKERS: <if blocked, exact reason + what's needed>
  FOLLOW-UP CAPTURED: <if execution surfaced new tasks, list them as one-line capture candidates>
```

### When NOT to fan out
- CAPTURE — always inline (one-shot quick task plan).
- STATUS / TRIAGE — inline.
- COMPACT — inline (file shuffling, not real work).
