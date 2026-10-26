---
description: 'Mandatory quality gate for code changes — security, tests, build, bug hunt. Fires on all code files.'
applyTo: '**/*.cs, **/*.ts, **/*.tsx, **/*.js, **/*.jsx, **/*.py'
---

## Code Quality Gate

When you **implement or modify** code (not just reading, explaining, or reviewing), run these 5 checks before declaring done. This is non-negotiable.

Skip this gate for: read-only analysis, code explanations, config-only changes, or when the user explicitly says "quick fix" / "just do it."

### 1. Security Scan

Before finishing, check your changes for:
- Injection vectors (SQL, XSS, command injection) — especially user input flowing into queries or HTML
- Auth/authz gaps — does the endpoint check permissions? Is the right scope enforced?
- Data exposure — are you returning more fields than the caller needs? PII in logs?
- Secrets — no hardcoded keys, connection strings, or tokens

If the change is security-sensitive (auth, payments, admin, data access), spawn `SE: Security` sub-agent for a deeper review.

### 2. Write Tests

For any non-trivial logic you wrote or changed:
- **For bug fixes: reproduce first.** Write a failing test that demonstrates the bug *before* fixing. The test failing proves you understand the bug; the test passing proves you fixed it. Don't change code without a test that distinguishes broken from fixed.
- Happy path — the main scenario works
- Edge cases — null, empty, boundary values, concurrent access
- Error paths — what happens when dependencies fail
- Regression — if it's a bug fix, the reproduce-first test above doubles as the regression guard

Match the project's test framework and existing test patterns. If tests already exist for the module, add to them.

### 3. Build & Run Tests

After implementation + tests, verify everything compiles and passes:
- Run the build (`dotnet build`, `npm run build`, etc.)
- Run ALL tests, not just your new ones — you might have broken something

If anything fails, fix the root cause and re-run. Don't move on with red.

### 4. Bug Hunt

Read through ALL your changes one more time. Look for:
- Off-by-one errors, null refs, race conditions
- Missing `IDisposable`/`await using` cleanup
- N+1 queries, unbounded collections, missing pagination
- Dead code, debug leftovers, commented-out code
- Naming inconsistencies with surrounding code
- If you changed behavior described in multiple places (docs, tables, constants), update ALL of them

### 5. Completion Check

Before handing back to the user, confirm:
- [ ] Code follows the project's existing patterns and conventions
- [ ] No compiler warnings introduced
- [ ] Tests pass
- [ ] Changes are focused — no unrelated refactoring snuck in

### When Verification Fails

- **Build fails** → read the error, fix the root cause, rebuild. Don't move on with red.
- **Test fails** → check if the test itself is correct first (stale assertion?), then fix the code. If the test expectation changed legitimately, update the test.
- **Security concern found** → fix before shipping. If the fix is non-trivial, flag it to the user with the risk level.
- **Multiple failures** → fix one at a time. Diagnose each; don't shotgun-fix.
