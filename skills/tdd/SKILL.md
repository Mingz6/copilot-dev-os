---
name: tdd
description: "Test-driven development with red-green-refactor loop. Enforces vertical slices — one test, one implementation, repeat. Use when: '/tdd', 'write tests first', 'red green refactor', 'TDD this', 'build this with tests', 'test-first', or any feature/fix where you want the agent to write failing tests before implementation."
---

# Test-Driven Development

## Philosophy

Tests verify **behavior through public interfaces**, not implementation details. Code can change entirely; tests shouldn't.

**Good tests** are integration-style: exercise real code paths through public APIs. They describe what the system does. A good test reads like a specification — "user can checkout with valid cart" tells you what capability exists. These survive refactors.

**Bad tests** are coupled to implementation: mock internal collaborators, test private methods, verify via external means (querying DB instead of using the interface). Warning sign: test breaks when you refactor, but behavior hasn't changed.

## Anti-Pattern: Horizontal Slices

**DO NOT** write all tests first, then all implementation.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
```

Tests written in bulk test imagined behavior, not actual behavior. You end up testing the shape of things rather than user-facing behavior. Each vertical slice responds to what you learned from the previous cycle.

## Workflow

### 1. Planning

Before writing any code:

- Confirm with user what interface changes are needed
- Confirm which behaviors to test (prioritize — can't test everything)
- Identify opportunities for deep modules (small interface, deep implementation)
- List behaviors to test (not implementation steps)
- Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors matter most?"

Use the project's `CONTEXT.md` vocabulary so test names and interface terms match the domain.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test FAILS
GREEN: Write minimal code to pass → test PASSES
```

This is your tracer bullet — proves the path works end-to-end.

### 3. Incremental Loop

For each remaining behavior:

```
RED:   Write next test → FAILS
GREEN: Minimal code to pass → PASSES
```

Rules:
- One test at a time
- Only enough code to pass the current test
- Don't anticipate future tests
- Keep tests focused on observable behavior
- Run the full test suite after each GREEN to catch regressions

### 4. Refactor

After all tests pass, look for refactor opportunities:

- Extract duplication
- Deepen modules (move complexity behind simple interfaces)
- Apply SOLID where natural
- Consider what new code reveals about existing code

**Never refactor while RED. Get to GREEN first.**

Run tests after each refactor step.

## Checklist Per Cycle

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
[ ] Full suite still passes
```

## Mocking Guidelines

- **Mock at boundaries only** — network, filesystem, external APIs, time
- **Never mock internal collaborators** — if you need to mock an internal class to test another, the design is wrong. Deepen the module or introduce a seam at a real boundary.
- **Prefer fakes over mocks** — in-memory implementations > spy assertions on call counts
- **One mock per test max** — if you need 3 mocks, the unit under test has too many dependencies

## Language-Specific References

- **TypeScript/JS**: See `javascript-typescript-jest` skill for Jest/Vitest patterns
- **Python**: See `python-fastapi-pytest` skill for pytest patterns
- **C#**: See `csharp-toolkit` skill for xUnit patterns

This skill is the **process**; those skills are the **syntax**.
