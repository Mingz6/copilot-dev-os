---
name: deploy-verify
user-invocable: true
description: 'Verify a deployment works on dev/test/prod using pipeline checks, API calls, and VS Code integrated browser. Use after deploying to an environment, when PO reports something is broken, or anytime you want to smoke-test a live environment. Standalone or called by other skills.'
---

# Deploy Verify

Smoke-test a live deployment environment after a merge or when a stakeholder reports a failure. Uses pipeline checks, the VS Code integrated browser for frontend checks, and `fetch_webpage` / API calls for backend checks.

## When to Run

1. **After PR merges to dev, test, or main** — verify the deployed code works before notifying PO
2. **After PO reports failure** — verify the issue yourself before replying (maybe it's a misunderstanding, stale cache, or unrelated)
3. **On demand** — `/deploy-verify {env} {what to check}`

## Input Formats

```
/deploy-verify test your-frontend-app /some-page/
/deploy-verify dev your-api /api/health
/deploy-verify test AB#1234             ← derive what to check from the work item
/deploy-verify prod your-api            ← pipeline check + read-only liveness ping
/deploy-verify all                      ← pipeline + liveness check across all repos + all envs
```

Minimal input — the skill infers what it can:
- **Environment**: `dev`, `test`, `prod`, or `all` (required).
  - `prod` = **read-only only** — pipeline checks, liveness pings, GET requests. No data modification.
  - `all` = check pipelines + liveness across all repos on dev, test, and prod
- **Repo or URL path**: optional — the skill can derive from a work item ID
- **Work item ID**: optional — if provided, fetch the item to understand what to verify

## Environment URL Map

Configure your own environment URL map. Key pattern:

| Repo | dev | test | prod |
|------|-----|------|------|
| your-frontend-app | `dev.your-app.com` | `test.your-app.com` | `your-app.com` |
| your-api | `dev.your-app.com/api/...` | `test.your-app.com/api/...` | `your-app.com/api/...` |
| your-cms | `cms.dev.your-app.com` | `cms.test.your-app.com` | `cms.your-app.com` |

## Verification Strategy

Pick the right approach based on what you're verifying:

### Frontend (React pages)

Use the **VS Code integrated browser** (`open_browser_page` → `read_page`):

1. Open the target URL
2. Wait for content to render (check snapshot for meaningful content, not just "Loading...")
3. Verify the expected elements are present (forms, buttons, text, headings)
4. Check console errors — distinguish expected 401s (unauthenticated CMS calls) from real errors
5. If the fix involves authenticated flows, note what you CAN verify vs what needs manual browser testing

```
Tools: open_browser_page, navigate_page, read_page, click_element, screenshot_page
```

### Backend (API endpoints)

Use `fetch_webpage` for public endpoints or terminal `curl` for endpoints that need headers:

1. Hit the health endpoint first: `{base_url}/api/health`
2. Hit the specific endpoint related to the fix
3. Check the response status and body
4. For authenticated endpoints — call unauthenticated and verify you get a proper 401 (not a 500 or crash)

### Database-dependent changes

If the fix involved a SQL script that needed to be run manually:
1. Check whether the script has been executed (query the data)
2. If not, note it — "SQL script hasn't been run on {env} yet, so this won't work until someone runs it"

## Verification Flow

### Step 1: Check Pipeline Status (always first)

Before hitting any URLs, verify the latest code actually deployed successfully. There's no point smoke-testing an endpoint if the deployment failed or is still running.

**For each repo involved**, check recent workflow runs on the target branch:

```bash
gh run list --repo your-org/{repo} --branch {branch} --limit 5 \
  --json name,status,conclusion,createdAt,headBranch,event \
  --jq '.[] | "\(.conclusion // .status)\t\(.name)\t\(.createdAt)\t\(.event)"'
```

Where `{branch}` = `dev`, `test`, or `main` depending on the environment.

**Timestamp formatting — never show raw UTC.** GitHub API returns UTC timestamps. Always convert to:
1. **Local time** — use the machine's timezone (e.g., `date -j -f "%Y-%m-%dT%H:%M:%SZ" "{utc}" "+%H:%M %Z"` on macOS)
2. **Relative time** — "3 min ago", "2 hours ago", "yesterday"

Display both: `10:29 AM PST (6 min ago)`. For runs older than today, show the date: `Mar 30, 5:19 PM PST (yesterday)`.

Helper to convert UTC to local + relative (run once, reuse for all timestamps):

```bash
python3 -c "
from datetime import datetime, timezone
import time

utc_str = '{utc_timestamp}'
utc_dt = datetime.fromisoformat(utc_str.replace('Z', '+00:00'))
local_dt = utc_dt.astimezone()
now = datetime.now(timezone.utc)
delta = now - utc_dt
mins = int(delta.total_seconds() / 60)
if mins < 1: rel = 'just now'
elif mins < 60: rel = f'{mins} min ago'
elif mins < 1440: rel = f'{mins // 60}h {mins % 60}m ago'
else: rel = f'{mins // 1440}d ago'
print(f'{local_dt.strftime(\"%b %d, %I:%M %p %Z\")} ({rel})')
"
```

**What to check:**
- **All deployment workflows green?** — Look for CD/deploy workflows (e.g., "Deploy", "CD", "Build and Deploy"). If the latest run failed, stop and report — the code isn't deployed.
- **Still running?** — If a deployment is `in_progress`, note it and wait or tell the user.
- **Non-deployment failures** — Workflows like "Environment Synchronization" or "CodeQL" failing are informational — flag them but don't block verification.

**Decision logic:**
- All deployment workflows **green** → proceed to Step 2
- Any deployment workflow **failed** → stop. Report: "Deployment failed — latest code isn't on {env}. Fix the pipeline first."
- Deployment **in progress** → report: "Deployment still running. Wait for it to finish, then re-run verify."
- **No recent runs** → note it ("No recent deployments found — the code may not be deployed yet") and proceed cautiously

**If checking "all" repos**, run this across all repos in your project. Use parallel curl/gh calls where possible.

### Step 2: Determine what to check

**If a work item ID is provided:**
1. Fetch fields + comments (same as devops skill Step 1)
2. Extract: what was fixed, which repo, what the user-visible behavior should be
3. Derive 1-3 smoke-test URLs/actions

**If a URL path is provided:**
→ Use it directly with the environment base URL

**If only a repo name:**
→ Hit the health/home endpoint as a basic liveness check

### Step 3: Run endpoint/UI checks

Execute each check and record:
- URL tested
- HTTP status / page content
- Pass/fail with evidence (what you saw)
- Any console errors or unexpected behavior

### Step 4: Report

Output a short verification report:

```
**Verification — {env} environment**

**Pipelines**
| Repo | Workflow | Status | Notes |
|------|----------|--------|-------|
| {repo} | {workflow name} | ✅ Pass | {local time} ({relative}) |
| {repo} | {workflow name} | ❌ Fail | {local time} ({relative}) — {link to run} |
| {repo} | {workflow name} | ⏳ Running | Started {local time} ({relative}) |

**Endpoints**
| Check | Result | Notes |
|-------|--------|-------|
| {URL or action} | ✅ Pass | {what you saw} |
| {URL or action} | ❌ Fail | {error or unexpected behavior} |
| {URL or action} | ⚠️ Can't verify | {requires auth / manual step} |
```

If everything passes → "Looks good on {env}. Safe to notify PO."
If pipeline failed → "Deployment failed — {details}. Fix the pipeline before verifying."
If something else fails → "Found an issue — {description}. Investigate before replying to PO."
If partially verifiable → "Verified what I can. {X} needs manual browser testing with logged-in session."

## Limitations

Be upfront about what this can and can't do:

- **No real auth sessions** — the integrated browser starts clean, no MSAL tokens. Can verify public pages but not authenticated user flows.
- **Prod is read-only** — allowed: pipeline checks (`gh run list`), liveness pings (`curl` GET), read-only API calls (GET endpoints). **Blocked on prod**: browser automation, clicking, form submission, POST/PUT/DELETE/PATCH requests, anything that modifies data. If the user asks to do something write-like on prod, refuse.
- **CMS content** — CMS changes may need a cache rebuild or service restart before they're visible.
- **Teams apps** — can't verify Teams bot interactions from a browser.

When a check requires something you can't do, say so and describe what the user should manually verify.

## Integration with Other Skills

This skill is called by:
- **`devops`** — after Step 5 (PR merged), verify before notifying PO
- **`pr-creator`** — after PR is merged and deployed, as an optional post-merge check
- **`devops-comment`** — when drafting a `ready-to-review` or when PO reports failure, verify first

Other skills should call deploy-verify by including: "Run `deploy-verify` to smoke-test the {env} environment before proceeding."

## Examples

### After deploying Bug 2 fix (auth redirect)

```
/deploy-verify test AB#1234
```

1. Check pipelines: `gh run list --repo your-org/your-frontend-app --branch test --limit 5` → CD workflow ✅
2. Derive from work item: Bug = public route redirects to sign-in
3. Open `https://test.your-app.com/some-page/` in browser
4. Check: page shows the expected form, not a redirect
5. Note: stale-token scenario can't be verified without logging in first
6. Report: "Pipelines green. ✅ Page loads without redirect. ⚠️ Stale-token flow needs manual browser test."

### After deploying API fix

```
/deploy-verify dev your-api /api/health
```

1. Check pipelines: `gh run list --repo your-org/your-api --branch dev --limit 5` → CD ✅, CodeQL ✅
2. `curl https://dev.your-app.com/api/health` → 200 OK
3. Report: "Pipelines green. ✅ Health endpoint returns 200."

### Checking all repos (CI/scripts-only changes)

```
/deploy-verify all
```

1. Check pipelines across all repos on dev and test branches
2. If changes are CI/scripts-only (no runtime code), pipelines ARE the verification — skip endpoint checks
3. Optionally do a quick liveness check on each app
4. Report: pipeline status table + liveness results
