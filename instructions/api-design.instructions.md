---
description: 'REST API design standards — URL conventions, Dapper patterns, pagination, response formats. Use when creating or modifying API endpoints, function app triggers, or HTTP handlers.'
applyTo: '**/*.cs'
---

# API Design Standards

REST API conventions for .NET services using Dapper.

## URL Conventions

- Plural nouns for resources: `/api/registrants`, `/api/cases`
- Kebab-case for multi-word segments: `/api/party-roles`, `/api/work-items`
- Use path parameters for identity: `/api/registrants/{id}`
- Use query parameters for filtering: `/api/registrants?status=active&page=1`
- No verbs in URLs — use HTTP methods: `POST /api/registrants` not `POST /api/createRegistrant`
- Nest only one level deep: `/api/registrants/{id}/notes` — deeper nesting gets a flat endpoint.

## HTTP Methods & Status Codes

| Method | Purpose | Success | Error |
|---|---|---|---|
| GET | Read | 200 OK | 404 Not Found |
| POST | Create | 201 Created | 400 Bad Request, 409 Conflict |
| PUT | Full update | 200 OK | 404, 400 |
| PATCH | Partial update | 200 OK | 404, 400 |
| DELETE | Remove | 204 No Content | 404 |

- Don't return 200 for everything — use the right status code.
- Use 409 Conflict for business rule violations (wrong state, duplicate).
- Use 422 for valid syntax but semantically wrong data.
- Always return ProblemDetails for 4xx/5xx (see error-handling instruction).

## Pagination

All list endpoints must support pagination. Use cursor-based for large datasets, offset for simple cases:

```csharp
// Request
GET /api/registrants?page=1&pageSize=25&sortBy=lastName&sortDirection=asc

// Response envelope
{
  "items": [...],
  "page": 1,
  "pageSize": 25,
  "totalCount": 142
}
```

- Never return unbounded results. Default `pageSize=25`, max `pageSize=100`.
- Always include `totalCount` for UI pagination controls.

## Dapper Patterns

### Parameter Objects

Use anonymous objects for simple queries, strongly-typed classes for complex ones:

```csharp
// Simple — anonymous object
var registrant = await conn.QuerySingleOrDefaultAsync<RegistrantDto>(
    "SELECT Id, FirstName, LastName FROM dbo.Registrant WHERE Id = @Id",
    new { Id = registrantId });

// Complex — parameter class for reuse and validation
var results = await conn.QueryAsync<CaseSearchDto>(sql, new CaseSearchParams
{
    Status = filter.Status,
    DateFrom = filter.DateFrom,
    DateTo = filter.DateTo,
    Page = filter.Page,
    PageSize = filter.PageSize
});
```

### Multi-Mapping (JOINs)

```csharp
var sql = """
    SELECT r.Id, r.FirstName, r.LastName, n.Id, n.Content, n.CreatedOn
    FROM dbo.Registrant r
    LEFT JOIN dbo.RegistrantNote n ON r.Id = n.RegistrantId
    WHERE r.Id = @Id
    """;

var registrant = (await conn.QueryAsync<RegistrantDto, NoteDto, RegistrantDto>(
    sql,
    (r, n) => { r.Notes.Add(n); return r; },
    new { Id = registrantId },
    splitOn: "Id"))
    .FirstOrDefault();
```

### Avoid N+1

Batch with `IN @Ids` instead of querying per item in a loop:

```csharp
var notes = await conn.QueryAsync<NoteDto>(
    "SELECT * FROM dbo.RegistrantNote WHERE RegistrantId IN @Ids",
    new { Ids = registrants.Select(r => r.Id) });
```

Always specify columns explicitly in SELECT — never `SELECT *`.

## Request Validation

Validate at the API boundary, not in domain logic:

- Use FluentValidation or DataAnnotations for input models.
- Return 400 with ProblemDetails listing all validation errors — not one at a time.
- Don't over-validate — trust internal service calls, validate external input.

## Versioning

- Use URL versioning: `/api/v1/registrants`, `/api/v2/registrants`
- Don't break existing consumers — add new fields, don't rename or remove.
- When breaking changes are unavoidable, create a new version and deprecate the old one.
