---
description: 'MCP server design — typed JSON contracts, deterministic local handlers, deny-by-default tool boundaries. Fires when editing TypeScript MCP server code.'
applyTo: '**/*mcp*/**/*.ts'
---

## MCP Server Design Rules

Tool boundaries are where agent systems break. Make output trustworthy, side effects explicit, and inputs paranoid.

### 1. Typed JSON contracts

- Every tool returns a known shape. Define the response type next to the tool definition. No "sometimes string, sometimes object" envelopes.
- Errors return via the SDK's `isError: true` content shape, not by throwing into stdout. Stdout is reserved for the JSON-RPC protocol.
- Validate inputs with `zod` schemas (or equivalent). Don't trust that the agent sent the field types you asked for.
- Add a smoke test per tool that pipes `tools/list` + a minimal `tools/call` through stdin and asserts the response shape.

### 2. Deterministic ops bypass the LLM

If the answer is computable without reasoning — list, count, lookup, status — make it a tool the agent calls directly. Don't make the agent reason about output format for things you can format yourself.

- `list_*`, `get_*`, `info_*`, `status_*` → pure local handlers, no model calls
- Heuristics, summaries, classification → fine to involve a model, but document which tools call out and which don't
- Mixing the two creates flaky, expensive tools

### 3. Deny-by-default at tool boundaries

When a tool accepts a path, URL, host, or shell-adjacent input, it must validate against an allowlist — not a blocklist.

- **File paths**: resolve, then check the result is under an explicit allowed root (reject path traversal with a prefix check after `path.resolve()`)
- **URLs**: parse, then check `host` is in an explicit allowlist
- **Shell commands**: don't. If unavoidable, no shell strings — only `execFile` with a fixed binary and array args
- **SQL identifiers**: escape via the driver's quoting helper, never by string concat

Reject loudly with a clear error message naming what was rejected and why. Silent normalization hides bugs.

### 4. Exit codes and lifecycle

- Process exits non-zero when initialization fails (missing env, bad config, unreachable upstream). Fail fast — don't surface auth errors mid-tool-call.
- All initialization log lines go to stderr. Stdout is JSON-RPC only.
- Long-lived state (caches, sessions) is opt-in and explicit; default to stateless tools.
- Pin `@modelcontextprotocol/sdk` with a caret range (`^1.29.0`), never unpinned or `latest` — the SDK's 2.x line isn't expected to keep the 1.x contract. All packages in this repo already do this; keep new packages consistent.

### 5. Provider-specific extension seams

When wrapping an LLM provider or external API, expose an `extraBody` / `providerOptions` bag for vendor-specific fields. Keeps the core abstraction clean while letting callers pass `tool_choice`, `response_format`, or other provider extras without you having to add every field.

### 6. Output normalization at boundaries

Tool outputs consumed by agents (or other tools) must be coerced to a known typed shape before crossing a boundary. No "sometimes string, sometimes object" responses.

- If a tool can fail or succeed, return a discriminated union: `{ ok: true, data: T } | { ok: false, error: string }`.
- If a tool calls an external service that returns varying shapes, normalize to your contract before returning — don't relay raw upstream responses.
- For MCP tools consumed by Copilot agents: always return MCP `content` blocks with a consistent structure. If metadata varies by call, put variable fields in a known `meta` key, not at top level.
- Downstream consumers should never need `typeof result === 'string'` checks — that's a contract failure.

### 7. Async and long-running operations

- If a tool's work can run longer than a few seconds (scrape, build, generation, external poll), don't block the call until completion. Kick off the work, return a handle/job id immediately, and expose a second tool (or the same tool with a status param) to poll progress.
- One shape that works: `POST /api/run/{name}` hands off to a bounded worker pool and returns immediately; the caller polls a runs table for status. Apply the same shape to any MCP tool wrapping a slow operation.
- Never make an agent's single tool call the only way to observe a long operation's outcome — if the calling session ends or times out, the job should still be inspectable independently.
