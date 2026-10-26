---
description: 'TypeScript 5.x targeting ES2022 — strict types, satisfies, const type params, no any. Use when writing or reviewing TS/TSX code.'
applyTo: '**/*.ts, **/*.tsx'
---

# TypeScript Development

TypeScript-specific rules. General clean code, error handling, security, and commenting are in their own instructions — this file covers only TS language and ecosystem patterns.

## General Guardrails

- Target TypeScript 5.x / ES2022 and prefer native features over polyfills.
- Use pure ES modules; never emit `require`, `module.exports`, or CommonJS helpers.
- Rely on the project's build, lint, and test scripts unless asked otherwise.

## Naming & Style

- PascalCase for classes, interfaces, enums, type aliases; camelCase for everything else.
- Skip interface prefixes like `I`; rely on descriptive names.
- Use kebab-case filenames (`user-session.ts`, `data-service.ts`) unless the project uses PascalCase.

## Type System

- Avoid `any` (implicit or explicit); prefer `unknown` plus narrowing.
- Use discriminated unions for events and state machines.
- Centralize shared contracts instead of duplicating shapes.
- Express intent with utility types (`Readonly`, `Partial`, `Record`).

## Async Patterns

- Use `async/await`; wrap awaits in try/catch with structured errors.
- Debounce configuration-driven updates and dispose resources deterministically.

## Architecture

- Follow the repository's DI or composition pattern; keep modules single-purpose.
- Keep transport, domain, and presentation layers decoupled.
- Instantiate clients outside hot paths and inject them for testability.
- Normalize external responses and map errors to domain shapes.

## Performance

- Lazy-load heavy dependencies and dispose them when done.
- Defer expensive work until users need it.
- Batch or debounce high-frequency events to reduce thrash.

## Logging

- `console.error` for caught exceptions, `console.warn` for unexpected-but-handled cases.
- Never log tokens, PII, passwords, or full request/response bodies to the browser console.
- With Application Insights JS SDK: track page views and meaningful custom events — not every click.