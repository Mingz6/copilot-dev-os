---
description: 'Git workflow standards — commit messages, squash strategy, branch hygiene. Fires on all code files.'
applyTo: '**/*.cs, **/*.ts, **/*.tsx, **/*.js, **/*.jsx, **/*.sql, **/*.ps1, **/*.sh, **/*.bicep, **/*.py'
---

## Git Workflow Standards

### Commit Messages

Format: `{type}: {what changed} (AB#{id})`

- `{type}`: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`, `infra`
- Lowercase after the prefix. Imperative mood. Max 72 chars first line.
- Always include the card number `(AB#{id})` — even on WIP commits. This makes `git log` searchable for both humans and Copilot.
- If no card: use `(AB#0)`. For personal repos: omit the suffix entirely.

**Banned verbs in commit messages:**

| Never use | Use instead |
|-----------|-------------|
| Implement | add, wire up, set up |
| Enhance | improve, extend, expand |
| Utilize | use |
| Leverage | use |
| Introduce | add |
| Ensure | (drop — state the consequence) |
| Address | fix |
| Incorporate | add |
| Facilitate | (drop — say what it does) |

**Good examples:**
```
fix: null ref on empty user list when date filter missing (AB#1234)
feat: add entity mutation tracking to message bus (AB#1235)
refactor: switch audit domain from system to user context (AB#1236)
fix: stale OAuth metadata cache — register as singleton (AB#0000)
infra: add event-monitor topic to Service Bus namespace (AB#1237)
chore: remove dead test project mappings from Pre-PR script (AB#1238)
```

**Bad examples:**
```
Implement OAuth configuration binding and conditional client registration
Add MockIdentityClient implementation for mock identity validation and flow status
Enhance FormatToValidCSharpIdentifier to support PascalCase conversion
```

### Commit Body (optional but encouraged for non-trivial changes)

When a commit does something worth explaining, add a body after a blank line:

```
fix: stale connection after CommitAsync — begin new tx before API call (AB#1234)

The UnitOfWork committed the transaction mid-flow, leaving subsequent
Dapper calls on a closed connection. Moved BeginAsync to right before
the registration call so the connection stays alive.
```

This is the "both human and Copilot friendly" standard: the subject line is scannable, the body has the *why* for anyone (human or AI) who needs to reconstruct context later.

### Squash Before Pushing

**Rule:** A feature branch should have 1-3 meaningful commits when the PR is created. Not 9 iteration commits.

**When to squash:**
- Before creating a PR (via `/pr-creator` or manually)
- When your branch has "fix the fix" commits (`fix CI build`, `address PR feedback`, `fix not completing`)
- When WIP commits tell a story that's only useful to you during development

**How:**
```bash
# Interactive rebase to squash. N = number of commits to review
git rebase -i HEAD~N

# In the editor: keep the first commit as "pick", change the rest to "squash" or "fixup"
# "squash" = combine and edit message
# "fixup" = combine and discard message (keeps the first one)
```

**When NOT to squash:**
- Logically separate changes that happen to be on the same branch (e.g., "add endpoint" + "add migration" = 2 distinct commits, keep both)
- Commits already pushed to a shared branch (test, dev, main) — never force-push shared branches

**Target commit structure for a typical feature:**
```
feat: add mock identity provider for dev environment (AB#1234)
feat: wire up account creation after mock validation (AB#1234)
```

Not:
```
Add MockIdentityClient implementation...
Add mock processing flow...
Add validation logic...
Implement configuration binding...
bugfix: fix mock not completing...
bugfix: use SingleOrDefault...
bugfix: disable mock in test...
bugfix: fix CI build...
bugfix: address PR feedback...
```

### Branch Naming (Work)

Format: `{type}/{author}#{AB-id}-{PascalCaseDescription}`

- `{type}`: `feature` (new work), `bugfix` (fixes), `chore` (infra/tooling), `refactor`, `docs`
- `{author}`: lowercase first name — `alice`, `bob`, `carol`, etc.
- `{AB-id}`: DevOps card number — use `0` when there's no card (`alice#0`)
- `{PascalCaseDescription}`: short, no spaces or dashes

**Examples:**
```
feature/alice#1234-DLQResilience
bugfix/bob#1235-ServiceBusDuplicateDetection
bugfix/alice#0-ConsoleTestSetup
```

**Before naming a branch:** run `git branch -r | grep {author}` to confirm the pattern used in the repo. Don't guess — check first.

### When to Commit

After completing a logical unit of work and passing verification, proactively offer to commit:

- Finished implementing a feature/fix and build + tests pass → stage + commit
- Multiple related files changed as one logical change → one commit
- Don't batch unrelated changes into a single commit — split by logical unit

### Branch Hygiene

- Delete local branches after PR is merged: `git branch -d {branch}`
- Fetch + prune regularly: `git fetch --prune`
- Don't accumulate stale local branches — run `git branch --merged main | grep -v main` periodically

### For Copilot / AI-Assisted Commits

When Copilot generates a commit message, apply these rules automatically:
1. Scan for banned verbs (see table above) — rewrite before committing
2. Verify `(AB#{id})` is present
3. Verify lowercase after prefix
4. If the message sounds like a README sentence, rewrite it as a terse action
