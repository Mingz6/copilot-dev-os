---
description: 'Observability standards — structured logging, tracing, health checks, Application Insights. Use when adding logging, telemetry, health checks, or Application Insights instrumentation.'
applyTo: '**/*.cs, **/*.ts, **/*.tsx'
---

# Observability Standards

Standards for logging, tracing, and monitoring in .NET and TypeScript services.

## Structured Logging (Serilog)

- Use structured log messages with named properties — never string interpolation in log templates:

```csharp
// Bad: loses structure, can't query by RegistrantId
_logger.LogInformation($"Processing registrant {registrantId}");

// Good: indexed, queryable in App Insights
_logger.LogInformation("Processing registrant {RegistrantId}", registrantId);
```

- Use PascalCase for property names in log templates (`{RegistrantId}`, not `{registrantId}`).
- Destructure complex objects with `@`: `_logger.LogInformation("Created {​@Result}", result);`

## Log Levels

| Level | When to use |
|---|---|
| `Trace` | Detailed diagnostic info (query parameters, loop iterations). Off in production. |
| `Debug` | Internal state useful for debugging. Off in production. |
| `Information` | Meaningful business events (user logged in, payment processed, sync completed). |
| `Warning` | Something unexpected but recoverable (retry succeeded, fallback used, deprecated API called). |
| `Error` | Operation failed but the service continues (failed API call, unhandled exception in a request). |
| `Critical` | Service is going down (startup failure, database unreachable, out of memory). |

Don't over-log. One `Information` entry per significant operation is enough. Don't log every method entry/exit.

## Correlation IDs

- Propagate a correlation ID across HTTP calls for distributed tracing.
- In .NET: use `Activity.Current?.Id` or a custom `X-Correlation-ID` header.
- Log the correlation ID as a scoped property so every log entry in a request includes it:

```csharp
using (_logger.BeginScope(new Dictionary<string, object> { ["CorrelationId"] = correlationId }))
{
    // All logs within this scope include CorrelationId
}
```

## Application Insights (.NET)

- Use `TelemetryClient` for custom events and metrics — don't build your own.
- Track custom events for business-significant actions: `_telemetry.TrackEvent("RegistrantApproved", props);`
- Use dependency tracking (automatic for HTTP, SQL) — don't log raw durations manually.
- Set cloud role name in `TelemetryInitializer` so services are distinguishable in the Application Map.

## Health Checks (.NET)

- Register health checks for every external dependency (database, Redis, external APIs).
- Use `/health` for liveness, `/health/ready` for readiness.
- Return degraded (not unhealthy) if a non-critical dependency is down.

```csharp
builder.Services.AddHealthChecks()
    .AddSqlServer(connectionString, name: "sql-db")
    .AddAzureBlobStorage(blobConnectionString, name: "blob-storage");
```

## Frontend (TypeScript)

- Use `console.error` for caught exceptions, `console.warn` for unexpected but handled cases.
- Never log sensitive data (tokens, PII, passwords) to the browser console.
- If using Application Insights JS SDK, track page views and custom events — don't track every click.

## What NOT to Log

- Passwords, tokens, secrets, connection strings, or PII.
- Full request/response bodies (log summaries or IDs instead).
- Successful health check pings (noise in production).
- Expected "no data found" scenarios — those aren't warnings.
