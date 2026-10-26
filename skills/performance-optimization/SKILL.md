---
name: performance-optimization
description: 'Cross-stack performance optimization best practices covering frontend, backend, and database. Includes checklists, anti-patterns, profiling guidance, and practical examples for .NET, React, Node.js, Python, and SQL. Use when: "why is this slow", "optimize this", "profile this function", "this query is taking too long", "reduce memory usage", "lazy loading", "benchmark this".'
---

# Performance Optimization Best Practices

Your goal is to help me optimize code for performance across any layer of the stack.

## General Principles

- **Measure First, Optimize Second:** Profile and benchmark before optimizing. Use tools like Chrome DevTools, Lighthouse, Py-Spy, dotTrace, or language-specific profilers.
- **Optimize for the Common Case:** Focus on frequently executed code paths.
- **Avoid Premature Optimization:** Write clear code first; optimize when needed.
- **Minimize Resource Usage:** CPU, memory, network, disk — always ask "can this be done with less?"
- **Set Performance Budgets:** Define limits for load time, memory, API latency. Enforce with automated checks.

---

## Frontend Performance

### Rendering and DOM
- Minimize DOM manipulations — batch updates, use document fragments.
- Use `React.memo`, `useMemo`, `useCallback` to prevent unnecessary re-renders.
- Use stable keys in lists (not array indices).
- Prefer CSS transitions/animations over JavaScript for GPU-accelerated effects.
- Defer non-critical rendering with `requestIdleCallback`.

### Asset Optimization
- Compress images (WebP, AVIF). Use `loading="lazy"` for images.
- Minify and bundle JS/CSS (esbuild, Webpack, Rollup). Enable tree-shaking.
- Subset fonts, use `font-display: swap`.
- Set long-lived cache headers with cache busting.

### Network
- Reduce HTTP requests. Enable HTTP/2 or HTTP/3.
- Use CDNs, Service Workers, `<link rel="preload">`.
- Use `defer`/`async` for non-critical scripts.

### JavaScript
- Don't block the main thread — use Web Workers for heavy computation.
- Debounce/throttle scroll, resize, input events.
- Clean up event listeners, intervals, DOM references to prevent memory leaks.
- Use Maps/Sets for lookups, TypedArrays for numeric data.

### Framework-Specific
#### React
- `React.memo`, `useMemo`, `useCallback` to avoid re-renders.
- Code-split with `React.lazy` + `Suspense`.
- Avoid anonymous functions in render.
- Profile with React DevTools Profiler.

#### Angular
- OnPush change detection. `trackBy` in `ngFor`. Lazy load modules.

#### Vue
- Computed properties over methods in templates. `v-show` vs `v-if`. Lazy load routes.

---

## Backend Performance

### Algorithms and Data Structures
- Choose the right data structure: arrays for sequential, hash maps for lookups, trees for hierarchy.
- Avoid O(n²) or worse — profile nested loops.
- Batch processing and streaming for large datasets.

### Concurrency
- Use async/await for I/O-bound work.
- Thread/worker pools to manage concurrency.
- Batch network/database calls to reduce round trips.
- Implement backpressure in queues and pipelines.

### Caching
- Cache expensive computations (Redis, Memcached).
- Use TTL-based, event-based, or manual invalidation. Stale cache is worse than no cache.
- Cache stampede protection with locks or request coalescing.

### API and Network
- Minimize payloads. Compress responses (gzip, Brotli).
- Always paginate large result sets. Use cursors for real-time data.
- Connection pooling for databases and external services.
- Rate limiting to protect APIs.

### Language-Specific

#### .NET
- `async/await` for I/O. `Span<T>`, `Memory<T>` for efficient memory.
- `IAsyncEnumerable<T>` for streaming.
- Profile with dotTrace, PerfView.
- Pool objects and connections.

#### Node.js
- Never block the event loop (`fs.readFileSync` in production).
- Clustering or worker threads for CPU-bound tasks.
- Streams for large data processing.
- Profile with `clinic.js` or `node --inspect`.

#### Python
- Built-in `dict`, `set`, `deque` for speed. `lru_cache` for memoization.
- `multiprocessing` or `asyncio` for parallelism.
- Profile with `cProfile`, `line_profiler`, `Py-Spy`.

#### Java
- Efficient collections. Thread pools (`Executors`).
- Tune JVM: `-Xmx`, `-Xms`, `-XX:+UseG1GC`.
- Profile with VisualVM, JProfiler.

---

## Database Performance

### Query Optimization
- Index columns used in WHERE, JOIN, ORDER BY. Drop unused indexes.
- **Never SELECT \*.** Select only needed columns.
- Parameterized queries for safety and plan caching.
- Analyze query plans with `EXPLAIN`.
- Avoid N+1 queries — use JOINs or batch queries.
- Paginate with `LIMIT`/`OFFSET` or cursors.

### Schema Design
- Normalize to reduce redundancy; denormalize for read-heavy workloads.
- Use the most efficient data types.
- Partition large tables. Archive old data.

### Transactions
- Keep transactions short to reduce lock contention.
- Use the lowest isolation level that meets consistency needs.

### Caching and Replication
- Read replicas for scaling reads. Monitor replication lag.
- Cache query results in Redis/Memcached.
- Sharding for horizontal scalability.

---

## Code Review Checklist

- [ ] Any O(n²) or worse algorithmic inefficiencies?
- [ ] Data structures appropriate for their use?
- [ ] Unnecessary computations or repeated work?
- [ ] Caching used where appropriate? Invalidation handled?
- [ ] Database queries optimized, indexed, free of N+1?
- [ ] Large payloads paginated, streamed, or chunked?
- [ ] Memory leaks or unbounded resource usage?
- [ ] Network requests minimized, batched, retried?
- [ ] Assets optimized, compressed, served efficiently?
- [ ] Blocking operations in hot paths?
- [ ] Performance-critical paths documented and tested?

---

## Profiling and Benchmarking

- **Profilers:** Chrome DevTools, Py-Spy, VisualVM, dotTrace, PerfView
- **Microbenchmarks:** `benchmark.js`, `pytest-benchmark`, JMH
- **Load testing:** k6, Gatling, Locust
- **A/B testing** for real-world impact measurement
- **Distributed tracing:** OpenTelemetry, Jaeger, Zipkin

## Scalability

- Horizontal scaling: stateless services, sharding, load balancers
- Auto-scaling with sensible thresholds
- Idempotent operations, retries, circuit breakers

## Cloud and Serverless

- Minimize cold starts: keep dependencies lean, functions warm
- Tune memory/CPU allocation
- Monitor cloud cost as a performance metric
