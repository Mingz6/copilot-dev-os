---
name: python-fastapi-pytest
user-invocable: true
description: |
  Python testing and FastAPI patterns — pytest, async tests, Azure OpenAI mocking, worker test harness. Use when: 'write pytest', 'test this endpoint', 'mock azure openai', 'add python tests', 'test this worker', 'pytest fixture', 'async test', 'mock httpx', 'test fastapi route', 'write a test for this python function'.
---

# Python FastAPI + pytest Skill

Covers pytest patterns for FastAPI services and APScheduler workers.

## Stack

- Python 3.12+
- `pytest` + `pytest-anyio` for async tests
- `httpx.AsyncClient` / `TestClient` for FastAPI endpoint tests
- `unittest.mock.patch` / `MagicMock` for Azure OpenAI and external service mocking
- Worker `run()` harness for APScheduler workers

---

## pytest Conventions

```python
# pytest.ini or pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"      # pytest-anyio global mode
testpaths = ["tests", "workers"]
```

Name files `test_{module}.py`, classes `Test{Feature}`, functions `test_{scenario}_{expected}`.

---

## FastAPI Endpoint Tests

```python
import pytest
from httpx import AsyncClient, ASGITransport
from web.app import app   # your FastAPI app

@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c

async def test_chat_returns_200(client):
    resp = await client.post("/chat", json={"message": "hello"})
    assert resp.status_code == 200
    data = resp.json()
    assert "reply" in data
```

For sync FastAPI apps use `TestClient` (no async needed):

```python
from fastapi.testclient import TestClient
client = TestClient(app)

def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
```

---

## Mocking Azure OpenAI

```python
from unittest.mock import AsyncMock, patch, MagicMock

@pytest.fixture
def mock_openai():
    with patch("core.llm.openai_client") as mock_client:
        mock_response = MagicMock()
        mock_response.choices[0].message.content = "Mocked LLM response"
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        yield mock_client

async def test_chat_uses_llm(client, mock_openai):
    resp = await client.post("/chat", json={"message": "hello"})
    assert resp.status_code == 200
    mock_openai.chat.completions.create.assert_called_once()
```

For TTS mocking:

```python
@pytest.fixture
def mock_tts():
    with patch("core.tts.openai_client") as mock_client:
        mock_client.audio.speech.create = AsyncMock(
            return_value=MagicMock(content=b"fake-mp3-bytes")
        )
        yield mock_client
```

---

## APScheduler Worker Tests

Worker `run()` signature: `run(params: dict, data_dir: Path, reports_dir: Path) -> dict | None`

```python
import pytest
from pathlib import Path
from workers.my_worker import run

@pytest.fixture
def tmp_dirs(tmp_path):
    data_dir = tmp_path / "data"
    reports_dir = tmp_path / "reports"
    data_dir.mkdir()
    reports_dir.mkdir()
    return data_dir, reports_dir

def test_run_no_change_returns_none(tmp_dirs):
    data_dir, reports_dir = tmp_dirs
    # Seed state to simulate no new data
    (data_dir / "my-worker-state.json").write_text('{"last_seen": "v1.0"}')
    result = run({}, data_dir, reports_dir)
    assert result is None

def test_run_returns_alert_on_change(tmp_dirs, mock_httpx):
    data_dir, reports_dir = tmp_dirs
    result = run({}, data_dir, reports_dir)
    assert result is not None
    assert "alert" in result
    assert result["priority"] in ("low", "normal", "high")

def test_run_handles_corrupt_state_file(tmp_dirs):
    data_dir, reports_dir = tmp_dirs
    (data_dir / "my-worker-state.json").write_bytes(b"NOT JSON{{{{")
    # Must not raise — should reset and continue
    result = run({}, data_dir, reports_dir)
    assert result is None or "alert" in result
```

---

## Mocking httpx in Workers

```python
import pytest
from unittest.mock import patch, MagicMock

@pytest.fixture
def mock_httpx():
    with patch("workers.my_worker.httpx") as mock:
        resp = MagicMock()
        resp.status_code = 200
        resp.json.return_value = {"items": [{"id": "a1", "price": 999}]}
        resp.raise_for_status = MagicMock()
        mock.get.return_value = resp
        yield mock
```

---

## Async Tests with anyio

```python
import anyio
import pytest

@pytest.mark.anyio
async def test_async_worker_function():
    result = await some_async_fn()
    assert result == expected

# Or with pytest-anyio global asyncio_mode = "auto" — no mark needed:
async def test_auto_async():
    result = await some_async_fn()
    assert result == expected
```

---

## Common Patterns

- Always assert on the **return shape** of `run()`: keys `alert`, `title`, `priority`, `url` all present when not None.
- Priority must be `"low"`, `"normal"`, or `"high"` — never `"default"`.
- State files must be written via `atomic_write_json` — tests that check post-run state should read from `data_dir`.
- Don't use `sleep` in tests — mock time or use `freezegun` for time-dependent logic.
- Keep tests independent: each test gets `tmp_path` fresh dirs, never shares state with siblings.
