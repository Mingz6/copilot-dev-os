---
description: 'Error handling patterns — Result pattern, ProblemDetails, retry/circuit breaker, Error Boundaries'
applyTo: '**/*.cs, **/*.ts, **/*.tsx, **/*.jsx'
---

# Error Handling Patterns

Consistent error handling across .NET backend and React frontend.

## .NET Backend

### Exception Categories

| Category | Example | How to handle |
|---|---|---|
| Validation errors | Missing required field, invalid email format | Return 400 with ProblemDetails. Don't throw. |
| Domain errors | Registrant not in correct state for action | Return 409/422 with ProblemDetails. Business rule violation. |
| Not found | Entity doesn't exist | Return 404. Don't throw `NullReferenceException`. |
| Infrastructure errors | DB timeout, external API down | Log + return 500/503. Retry if idempotent. |
| Unexpected/bugs | `NullReferenceException`, `IndexOutOfRange` | Let it propagate. Global handler returns 500. |

### ProblemDetails (RFC 9457)

Use `ProblemDetails` for all API error responses — consistent structure for clients to parse:

```csharp
return Results.Problem(
    title: "Registrant not found",
    detail: $"No registrant with ID {registrantId} exists",
    statusCode: StatusCodes.Status404NotFound
);
```

Don't invent custom error response shapes. Clients expect `title`, `status`, `detail`, `type`.

### Guard Clauses, Not Deep Nesting

Validate at the boundary, return early:

```csharp
public async Task<IResult> Handle(UpdateRegistrantCommand command)
{
    if (command.RegistrantId <= 0)
        return Results.Problem(title: "Invalid ID", statusCode: 400);

    var registrant = await _repo.GetByIdAsync(command.RegistrantId);
    if (registrant is null)
        return Results.Problem(title: "Not found", statusCode: 404);

    // Happy path — no nesting
    registrant.UpdateName(command.Name);
    await _repo.SaveAsync();
    return Results.Ok();
}
```

### Retry & Circuit Breaker (Polly)

For external HTTP calls and transient failures:

```csharp
services.AddHttpClient("ExternalApi")
    .AddTransientHttpErrorPolicy(p => p.WaitAndRetryAsync(3, attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt))))
    .AddTransientHttpErrorPolicy(p => p.CircuitBreakerAsync(5, TimeSpan.FromSeconds(30)));
```

- Retry only idempotent operations (GET, PUT). Don't retry POST blindly.
- Circuit breaker prevents cascading failures — fail fast instead of waiting for timeouts.
- Always set timeouts on `HttpClient` — don't wait forever.

### Don't Catch Everything

```csharp
// Bad: swallows all exceptions, hides bugs
try { await ProcessPayment(); } catch { }

// Bad: too broad, loses context
try { await ProcessPayment(); } catch (Exception ex) { _logger.LogError("Error"); }

// Good: catch what you expect, let the rest propagate
try { await _httpClient.GetAsync(url); }
catch (HttpRequestException ex) { _logger.LogWarning(ex, "Payment API unreachable for {OrderId}", orderId); }
```

## React Frontend

### Error Boundaries

Wrap route-level or feature-level components — not every component:

```tsx
<ErrorBoundary fallback={<ErrorPage />}>
  <RegistrantProfile />
</ErrorBoundary>
```

- Put Error Boundaries at **route level** and around **data-fetching components**.
- Don't wrap every small component — that's noise.
- Show a meaningful fallback with a retry action.

### Async Error Handling

```tsx
try {
  const response = await api.updateRegistrant(data);
  showSuccess("Saved");
} catch (error) {
  if (error instanceof ApiError && error.status === 409) {
    showWarning("Registrant state changed — please refresh");
  } else {
    showError("Something went wrong. Try again or contact support.");
  }
}
```

- Map backend ProblemDetails to user-friendly messages.
- Don't show raw error messages or stack traces to users.
- Log to console.error (or App Insights) for debugging.

### Loading & Error States

Every data fetch needs three states — don't skip the error state:

```tsx
if (isLoading) return <Spinner />;
if (error) return <ErrorMessage message="Failed to load registrant" onRetry={refetch} />;
return <RegistrantDetails data={data} />;
```
