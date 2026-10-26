---
description: 'Guidelines for GitHub Copilot to write comments to achieve self-explanatory code with less comments. Examples are in JavaScript but it should work on any language that has comments.'
applyTo: '**/*.cs, **/*.ts, **/*.tsx, **/*.js, **/*.jsx, **/*.py, **/*.sql'
---

# Self-explanatory Code Commenting

**Write code that speaks for itself. Comment only when necessary to explain WHY, not WHAT.**

## Decision Framework

Before writing a comment, ask:
1. Is the code self-explanatory? → No comment needed
2. Would a better name eliminate the need? → Refactor instead
3. Does this explain WHY, not WHAT? → Good comment
4. Will this help future maintainers? → Good comment

## Comment When

- Complex business logic or domain rules
- Non-obvious algorithm choices
- Regex patterns
- API constraints, gotchas, or workarounds
- Public API docs (JSDoc / XML doc)

## Never Comment

- What the code already says (`counter++; // Increment counter`)
- Commented-out dead code — delete it, git has history
- Changelog entries (`// Modified by X on Y`) — that's git blame's job
- Outdated information that contradicts the code

## Annotation Tags

Use these prefixes for actionable comments:
`TODO`, `FIXME`, `HACK`, `NOTE`, `WARNING`, `PERF`, `SECURITY`, `DEPRECATED`
