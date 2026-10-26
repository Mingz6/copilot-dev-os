---
description: 'Universal clean code standards — applies to all languages'
applyTo: '**/*.cs, **/*.ts, **/*.tsx, **/*.js, **/*.jsx, **/*.py, **/*.sql, **/*.sh'
---

# Clean Code Standards

Universal principles for writing production-grade code. Language-agnostic — applies everywhere.

## Functions

- Keep functions short and single-purpose. If a function does two things, split it.
- Use early returns and guard clauses — avoid deep nesting.
- Limit parameters: 3 or fewer. Group related params into an object/type.

```typescript
// Bad: deeply nested
function process(user) {
  if (user) {
    if (user.isActive) {
      if (user.hasPermission) {
        // actual logic buried 3 levels deep
      }
    }
  }
}

// Good: guard clauses
function process(user) {
  if (!user || !user.isActive || !user.hasPermission) return;
  // actual logic at top level
}
```

## Naming

- No magic numbers or strings — use named constants.
- Name booleans as questions: `isActive`, `hasPermission`, `canEdit`.
- Name functions as verbs: `calculateTotal`, `fetchUser`, `validateInput`.
- Name variables as nouns describing what they hold, not how they're computed.

```typescript
// Bad
if (status === 3) { ... }
const d = new Date();

// Good
const STATUS_INACTIVE = 3;
if (status === STATUS_INACTIVE) { ... }
const registrationDate = new Date();
```

## Immutability

- Default to `const` / `readonly` / `final`. Use mutable only when mutation is required.
- Prefer creating new objects over mutating existing ones.
- Use `Readonly<T>`, `ReadonlyArray<T>`, `Object.freeze()` at boundaries.

## Error Handling

- Include context in error messages — what operation failed and with what input.
- Fail fast at system boundaries (user input, API responses, config). Trust internals.
- Never swallow errors silently. Log or rethrow with context.

```typescript
// Bad
throw new Error('failed');

// Good
throw new Error(`Failed to fetch registrant ${registrantId}: ${response.status} ${response.statusText}`);
```

## Simplicity

- No premature abstraction — don't create helpers, wrappers, or utilities for one-time operations.
- Don't design for hypothetical future requirements.
- Prefer flat over nested, explicit over implicit, boring over clever.
- If removing code doesn't break anything, it shouldn't exist.
- **Length test**: if you wrote 200 lines and it could be 50, rewrite it. Strategy patterns, factories, and config classes for one-shot logic are slop.
- **Senior-engineer test**: would a senior at FAANG call this overcomplicated in code review? If yes, simplify before committing.

## Edge Cases

- Handle edge cases before the happy path (guard clauses pattern).
- Check for null/undefined/empty at system boundaries, not deep inside business logic.
- Empty collections are valid — don't special-case them unless semantics differ.

## Boy Scout Rule — Clean What You Touch

When editing a file, fix spacing, imports, and style issues in the code you touched — but don't reformat unrelated code. Match the file's existing conventions.

- Remove unused imports in any import block you modify.
- Sort imports by convention (framework → third-party → local) when you add or change one.
- Fix inconsistent blank lines in functions you edit (1 blank line between top-level declarations, 0 extra inside functions).
- Don't introduce style changes outside your diff — keep PRs reviewable.

## AI Slop — What Not to Generate

"AI slop" = code smells that scream "an LLM wrote this without thinking." Reviewers can call it out by name. Cut it before committing.

The four big ones:

1. **Obvious comments restating code.** `// increment counter` above `counter++`. If the next line says it, drop the comment.
2. **Over-defensive null checks on guaranteed values.** Don't `if (user != null)` when the type system or a guard 3 lines up already proved it. Trust the type system; check at boundaries only.
3. **Redundant existence checks.** `if (arr && arr.length > 0)` when `arr` is typed as `T[]`. `if (typeof x === 'string')` when `x: string`. Same for `hasOwnProperty` on objects you just constructed.
4. **One-shot helpers and wrappers.** `function getUserName(u) { return u.name; }` used in one place. Inline it. Premature abstraction is slop.

When refactoring AI-generated code: preserve behavior, no public API changes, keep type hints, no new abstractions. Just delete the slop.
