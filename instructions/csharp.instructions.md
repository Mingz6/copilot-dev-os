---
description: 'C# coding standards — complements clean-code.instructions.md with C#-specific rules'
applyTo: '**/*.cs'
---

# C# Coding Standards

C#-specific rules that complement the universal clean-code instructions. Targets C# 12+ / .NET 8+.

## Null Handling

- Always use `is null` / `is not null` — never `== null` / `!= null`.
- Declare variables non-nullable by default. Only use `?` when null is a valid domain state.
- Trust C# null annotations — don't add null checks when the type system says a value can't be null.
- Use `ArgumentNullException.ThrowIfNull()` at public API boundaries.

## Language Features

- Prefer pattern matching and switch expressions over if/else chains.
- Use `nameof()` instead of string literals for member references.
- Use file-scoped namespaces (`namespace Foo;` not `namespace Foo { }`).
- Prefer collection expressions (`[1, 2, 3]`) and `..` spread operator where supported.
- Use primary constructors for simple DI wiring (e.g., `public class MyService(ILogger logger)`).
- Use records for immutable data transfer objects.

## Naming

- PascalCase for public members, types, methods, properties, constants.
- camelCase with `_` prefix for private fields (`_logger`, `_repository`).
- Prefix interfaces with `I` (`IUserService`, `IRepository<T>`).
- Suffix async methods with `Async` (`GetUserAsync`, `SaveChangesAsync`).

## Formatting

- Apply `.editorconfig` rules when present.
- One class per file. Filename matches the type name.
- Opening brace on its own line (Allman style).
- `using` directives at file top, sorted: System → Microsoft → third-party → project.

## Architecture Layers

When working in layered / DDD-style projects:

- **Domain**: Entities, value objects, domain services, domain events. No infrastructure dependencies. Business rules live here, not in application services.
- **Application**: Commands, queries, DTOs, orchestration. Thin — delegates to domain.
- **Infrastructure**: Repositories, external service adapters, EF/Dapper mappings. Implements domain interfaces.
- Keep aggregate boundaries tight — don't let one aggregate reach into another's internals.
- Prefer domain events for cross-aggregate side effects over direct coupling.

## Common Anti-Patterns

- Don't use `async void` except for event handlers.
- Don't call `.Result` or `.Wait()` on tasks — use `await`.
- Don't catch `Exception` broadly — catch specific types or let it propagate.
- Don't use `string.Format()` — use interpolation (`$"Hello {name}"`).
- Don't use `DateTime.Now` — use `DateTime.UtcNow` or inject `TimeProvider`.
