---
description: 'Python coding standards — type hints, Pydantic, async, httpx, logging, secrets. Complements clean-code.instructions.md with Python-specific rules.'
applyTo: '**/*.py'
---

## Python Coding Standards

Python 3.11+. Applies to FastAPI services, APScheduler workers, and Python MCP packages.

### Type Hints

- All function signatures must have type hints — parameters and return type.
- Use `from __future__ import annotations` for forward references.
- Prefer `X | None` over `Optional[X]` (Python 3.10+ union syntax).
- Use `TypeAlias` for complex types used in multiple places.

```python
# ✅
def get_rate(symbol: str, date: str | None = None) -> float | None: ...

# ❌
def get_rate(symbol, date=None): ...
```

### Pydantic (FastAPI / request-response schemas)

- Use Pydantic models for all FastAPI request bodies and responses — never return raw `dict`.
- Use `model_config = ConfigDict(str_strip_whitespace=True)` on models that parse user input.
- Validate at the boundary (API endpoint / worker `run()` params) — don't re-validate internally.

```python
from pydantic import BaseModel, Field

class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=4000)

class ChatResponse(BaseModel):
    reply: str
    audio_url: str | None = None
```

### Async

- FastAPI endpoints: `async def`. Never block the event loop.
- CPU-bound or sync-only operations: `await asyncio.to_thread(sync_fn, *args)`.
- Don't mix `asyncio.run()` inside an already-running event loop — use `anyio` or structured concurrency.

```python
# ✅ offload blocking I/O
async def get_report() -> Report:
    data = await asyncio.to_thread(load_from_disk, path)
    return Report(data=data)
```

### HTTP Calls

- Use `httpx` for all HTTP. Always set an explicit `timeout`.
- Never use `requests` inside async code (blocks the event loop).
- For retries: use `tenacity` with exponential backoff — not manual loops.

```python
import httpx

resp = httpx.get(url, timeout=10)          # sync
resp = await client.get(url, timeout=10)   # async
```

### Logging

- Use the `logging` module — never `print()` in production code.
- Log at `INFO` for normal flow, `WARNING` for recoverable issues, `ERROR` for failures.
- Include context in log messages (worker name, URL, item ID).

```python
import logging
log = logging.getLogger(__name__)

log.info("Checked %d items, %d new", total, new_count)
log.warning("Rate limit hit, backing off %ds", delay)
log.error("Failed to fetch %s: %s", url, e)
```

### Secrets

- Secrets via `os.environ` — never hardcoded.
- Add every new env var to `.env.example` in the same commit.
- Fail fast if required vars are missing (`os.environ["KEY"]` raises immediately; `os.getenv("KEY", "")` hides missing vars).

### Worker-center Specifics

- `run(params, data_dir, reports_dir)` → return `{"alert": str, "title": str, "priority": "low|normal|high", "url": str}` or `None`.
- `priority` must be `"low"`, `"normal"`, or `"high"` — never `"default"`.
- State files: always write via `workers.io_utils.atomic_write_json` — never `path.write_text(json.dumps(...))`.
- Workers must be idempotent: same inputs on retry = same result.
