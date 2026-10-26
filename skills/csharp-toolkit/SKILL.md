---
name: csharp-toolkit
description: 'C# / .NET reference — async, xUnit testing, XML docs, DI, SOLID, GoF patterns. Use when writing/reviewing .NET code for quality, patterns, testing, or docs. Routes: this skill = reference material; csharp-dotnet-janitor agent = cleanup/modernization on existing code; code-perfectionist agent = implement + 5-phase validation.'
---

# C# / .NET Toolkit

Reference material for writing and reviewing C# / .NET code. Covers async, testing, XML docs, DI, architecture patterns, and SOLID.

**When to use this skill vs. a C#/.NET agent:**

| Task | Use |
|------|-----|
| Look up correct async pattern, xUnit setup, DI lifetime | this skill |
| Implement a new feature with validation | `code-perfectionist` agent |
| Modernize old code, remove dead code, fix warnings | `csharp-dotnet-janitor` agent |
| Review PR for patterns/SOLID violations | this skill + `se-security-reviewer` agent for security |

---

## Async Programming

### Naming & Return Types
- Use the `Async` suffix for all async methods
- Return `Task<T>` when the method returns a value, `Task` when it doesn't
- Consider `ValueTask<T>` for high-performance scenarios to reduce allocations
- Avoid `async void` except for event handlers

### Exception Handling
- Use try/catch around await expressions
- Use `ConfigureAwait(false)` in library code to prevent deadlocks
- Use `Task.FromException()` only in synchronous methods returning Task — in async methods, just throw normally

### Performance
- Use `Task.WhenAll()` for parallel execution
- Use `Task.WhenAny()` for timeouts or first-completed
- Avoid unnecessary async/await when simply passing through task results
- Use cancellation tokens for long-running operations

### Pitfalls
- Never use `.Wait()`, `.Result`, or `.GetAwaiter().GetResult()` in async code
- Don't mix blocking and async code
- Always await Task-returning methods
- Use `IAsyncEnumerable<T>` for async streams

---

## xUnit Testing

### Project Setup
- Separate test project: `[ProjectName].Tests`
- Reference `Microsoft.NET.Test.Sdk`, `xunit`, `xunit.runner.visualstudio`
- Run with `dotnet test`

### Test Structure
- `[Fact]` for single tests, `[Theory]` with `[InlineData]`/`[MemberData]`/`[ClassData]` for data-driven
- Follow AAA pattern (Arrange-Act-Assert)
- Name tests: `MethodName_Scenario_ExpectedBehavior`
- Constructor for setup, `IDisposable.Dispose()` for teardown
- `IClassFixture<T>` for shared context within a class
- `ICollectionFixture<T>` for shared context across classes

### Assertions
- `Assert.Equal` for value equality, `Assert.Same` for reference equality
- `Assert.Contains`/`Assert.DoesNotContain` for collections
- `Assert.Throws<T>` / `await Assert.ThrowsAsync<T>` for exceptions
- Consider FluentAssertions for more readable assertions

### Mocking
- Use Moq or NSubstitute alongside xUnit
- Mock dependencies via interfaces to isolate units under test
- Consider a DI container for complex test setups

### Organization
- Group tests by feature or component
- `[Trait("Category", "CategoryName")]` for categorization
- `ITestOutputHelper` for test diagnostics
- `Skip = "reason"` in fact/theory attributes for conditional skipping

### Integration Testing with WebApplicationFactory

```csharp
public class ApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<DbConnection>();
                services.AddScoped<DbConnection>(_ =>
                    new SqlConnection(TestConstants.TestConnectionString));
            });
        }).CreateClient();
    }

    [Fact]
    public async Task GetRegistrant_ReturnsOk()
    {
        var response = await _client.GetAsync("/api/registrants/1");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

- One `WebApplicationFactory<Program>` per test class via `IClassFixture`
- Override services in `WithWebHostBuilder` to swap external dependencies
- `[Trait("Category", "Integration")]` to separate from unit tests
- For Dapper: point test `DbConnection` at a test database with known seed data
- Wrap each test in a transaction and roll back for isolation

| Scenario | Test type |
|---|---|
| Business logic in a service/handler | Unit test (mock deps) |
| Dapper query returns correct shape | Integration test (real DB) |
| API endpoint returns correct status/body | Integration test (WebApplicationFactory) |
| Input validation rules | Unit test |

---

## XML Documentation

### General Rules
- `<summary>` — brief, one-sentence, present-tense third-person verb
- `<remarks>` — additional info, implementation details, usage notes
- `<see langword>` for keywords (`null`, `true`, `false`)
- `<c>` for inline code, `<code>` for blocks (within `<example>`)
- `<see cref>` for inline references, `<seealso>` for standalone references
- `<inheritdoc/>` to inherit from base classes/interfaces

### Methods
- `<param>` — noun phrase, no data type. Start with an article.
- Boolean params: `<see langword="true" /> to ...; otherwise, <see langword="false" />.`
- Out params: "When this method returns, contains ..."
- `<returns>` — noun phrase with article, no data type
- `<typeparam>` / `<typeparamref>` for generic type parameters

### Constructors
- Summary: "Initializes a new instance of the \<Class\> class."

### Properties
- Read-write: "Gets or sets..."
- Read-only: "Gets..."
- Boolean: "Gets [or sets] a value that indicates whether..."
- `<value>` — noun phrase. Add default in separate sentence if applicable.

### Exceptions
- `<exception cref>` — document all directly thrown exceptions
- Describe the condition, not "Thrown if..." — just state the condition directly

---

## Dependency Injection & Services

- Constructor injection is the default. Use primary constructor syntax (`public class MyClass(IDependency dep)`) in C# 12+.
- Register with appropriate lifetimes: Singleton (stateless/thread-safe), Scoped (per-request), Transient (per-resolution).
- Depend on interfaces (prefix with `I`), not concrete types.
- Null-check injected deps in the constructor body or use `ArgumentNullException.ThrowIfNull(dep)`.

## Design Patterns

### Patterns to prefer
- **Command Pattern** — generic base classes (`CommandHandler<TOptions>`), `ICommandHandler<TOptions>` interface.
- **Factory Pattern** — complex object creation with service provider integration.
- **Repository Pattern** — async data access interfaces, provider abstractions for connections.
- **Provider Pattern** — external service abstractions (DB, AI), clear contracts, configuration handling.
- **Resource Pattern** — `ResourceManager` for localized messages, separate `.resx` files.

### GoF patterns commonly seen in .NET
Command, Factory, Template Method, Strategy. Verify correct use during review — don't cargo-cult.

## Architecture

- Namespace convention: `{Core|Console|App|Service}.{Feature}`.
- Keep Core projects free of framework dependencies. Console/App projects compose.
- Interface segregation — small focused interfaces beat fat ones.

## SOLID

- **S** Single Responsibility — one reason to change per class.
- **O** Open/Closed — extend via new code, not by modifying existing.
- **L** Liskov — subtypes fully substitutable for their base.
- **I** Interface Segregation — small, client-specific interfaces.
- **D** Dependency Inversion — depend on abstractions, not concretions.

## Error Handling & Logging

- Use `Microsoft.Extensions.Logging`. Structured logging with named placeholders (`logger.LogInformation("User {UserId} logged in", userId)`).
- Include scope with `logger.BeginScope(...)` for correlated multi-call operations.
- Throw specific exception types with descriptive messages. Don't catch `Exception` unless re-throwing or logging + handling.

## Performance & Security

- C# 12+ features and .NET 8+ optimizations where applicable.
- Parameterized queries for all database access (Dapper, EF Core) — never string concat.
- Input validation at API boundaries. Don't trust anything from outside.

---

## Review Checklist

Work through each area when reviewing a PR:

- [ ] **Patterns** — Command / Factory / Provider / Repository correctly implemented? Beneficial patterns missing?
- [ ] **GoF** — Command, Factory, Template Method, Strategy correct?
- [ ] **SOLID** — any principle violations?
- [ ] **Async** — no `.Wait()` / `.Result`, correct `ConfigureAwait(false)` in library code, `Task.WhenAll` for parallel?
- [ ] **Performance** — proper disposal, pooled resources, parallel opportunities?
- [ ] **Maintainability** — clear SoC, consistent error handling, config done properly?
- [ ] **Testability** — deps behind interfaces, mockable, AAA-compatible?
- [ ] **Security** — input validation, secure credential handling, parameterized queries, safe exception handling?
- [ ] **Documentation** — XML docs for public APIs, params + returns described?
- [ ] **Clean Code** — consistent style, appropriate size, minimal complexity, no duplication?
