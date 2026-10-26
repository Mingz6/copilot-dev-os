# Delegate Task Queue

File-backed task queue for Copilot agent delegation. Tasks are markdown files that move through folders as they progress.

## How It Works

```
queue/    →    active/    →    done/
(waiting)     (agent working)   (finished — delete anytime)
```

**Generate tasks:** In any chat, say `/delegate <tasks or doc reference>`. The skill splits them into independent streams and writes one `.md` file per stream to `queue/`.

**Pick up a task:** Open a new chat (Cmd+Shift+I) and say:
- `/delegate 2024-01-15-my-feature.md` — pick a specific task
- `/delegate` — pick the oldest queued task automatically

**Check status:** `/delegate status`

## File Naming

`{YYYY-MM-DD}-{slug}.md` — date first for natural FIFO ordering.

## Cleanup

- `done/` files accumulate as a work log. Delete them whenever.
- If a file sits in `active/` but no agent is working on it, the previous chat probably died. Move it back to `queue/` to retry.
