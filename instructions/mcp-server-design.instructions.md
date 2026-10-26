---
description: 'MCP server design — typed JSON contracts, deterministic local handlers, deny-by-default tool boundaries. Fires when editing TypeScript MCP server code.'
applyTo: '**/mcp-servers/**/*.ts'
---

## MCP Server Design Rules

Tool boundaries are where agent systems break. Make output trustworthy, side effects explicit, and inputs paranoid.

### 1. Typed JSON contracts

- Every tool returns a known shape. Define the response type next to the tool definition. No "sometimes string, sometimes object" envelopes.
- Errors return via the SDK's `isError: true` content shape, not by throwing into stdout. Stdout is reserved for the JSON-RPC protocol.
- Validate inputs with `zod` schemas (or equivalent). Don't trust that the agent sent the field types you asked for.
- Add a smoke test per tool that pipes `tools/list` + a minimal `tools/call` through stdin and asserts the response shape. The two MCP servers in this repo (`brain-mcp`, `flywheel`) already do this — copy the pattern.

### 2. Deterministic ops bypass the LLM

If the answer is computable without reasoning — list, count, lookup, status — make it a tool the agent calls directly. Don't make the agent reason about output format for things you can format yourself.

- `list_*`, `get_*`, `info_*`, `status_*` → pure local handlers, no model calls
- Heuristics, summaries, classification → fine to involve a model, but document which tools call out and which don't
- Mixing the two creates flaky, expensive tools

### 3. Deny-by-default at tool boundaries

When a tool accepts a path, URL, host, or shell-adjacent input, it must validate against an allowlist — not a blocklist.

- **File paths**: resolve, then check the result is under an explicit allowed root (see `resolveBrainPath` in `brain-mcp/src/brain.ts` for the canonical pattern — rejects path traversal via prefix check after `path.resolve()`)
- **URLs**: parse, then check `host` is in an explicit allowlist
- **Shell commands**: don't. If unavoidable, no shell strings — only `execFile` with a fixed binary and array args
- **SQL identifiers**: escape via the driver's quoting helper, never by string concat

Reject loudly with a clear error message naming what was rejected and why. Silent normalization hides bugs.

### 4. Exit codes and lifecycle

- Process exits non-zero when initialization fails (missing env, bad config, unreachable upstream). Fail fast — don't surface auth errors mid-tool-call. See the `flywheel` server's `GITHUB_TOKEN` check at startup.
- All initialization log lines go to stderr. Stdout is JSON-RPC only.
- Long-lived state (caches, sessions) is opt-in and explicit; default to stateless tools.

### 5. Provider-specific extension seams

When wrapping an LLM provider or external API, expose an `extraBody` / `providerOptions` bag for vendor-specific fields. Keeps the core abstraction clean while letting callers pass `tool_choice`, `response_format`, or other provider extras without you having to add every field.

### Reference

- `mcp-servers/packages/my-mcp/src/index.ts` — path containment checks, deterministic local tool patterns
- `mcp-servers/packages/my-mcp/src/tools.ts` — startup env checks, `toolError` error envelope helper
- `mcp-servers/packages/my-mcp/src/index.test.ts` — contract test pattern
