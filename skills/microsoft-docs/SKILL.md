---
name: microsoft-docs
description: 'Query official Microsoft documentation, look up API references, find working code samples, and verify SDK code. Uses Microsoft Learn MCP as the default, with Context7 and Aspire MCP for content outside learn.microsoft.com. Catches hallucinated methods, wrong signatures, and deprecated patterns.'
---

# Microsoft Docs & Code Reference

Research and verify Microsoft APIs, SDKs, and documentation. Covers learn.microsoft.com and docs that live outside it (VS Code, GitHub, Aspire).

---

## Tools

| Need | Tool | Example |
|------|------|---------|
| Concepts, guides, tutorials | `microsoft_docs_search` | `"Azure Functions Python v2 programming model"` |
| Working code samples | `microsoft_code_sample_search` | `query: "upload blob managed identity", language: "python"` |
| Full page content | `microsoft_docs_fetch` | Fetch URL from search (for overloads, full signatures) |

Use `microsoft_docs_fetch` after search when you need complete tutorials, all config options, or when search excerpts are truncated.

### CLI Alternative

If the Learn MCP server is not available:

```bash
npx @microsoft/learn-cli search "BlobClient UploadAsync Azure.Storage.Blobs"
```

| MCP Tool | CLI Command |
|----------|-------------|
| `microsoft_docs_search(query: "...")` | `mslearn search "..."` |
| `microsoft_code_sample_search(query: "...", language: "...")` | `mslearn code-search "..." --language ...` |
| `microsoft_docs_fetch(url: "...")` | `mslearn fetch "..."` |

---

## API Verification Workflow

Before generating code using Microsoft SDKs:

1. **Confirm method/package exists** — `microsoft_docs_search(query: "[ClassName] [MethodName] [Namespace]")`
2. **Fetch full details** (for overloads/complex params) — `microsoft_docs_fetch(url: "...")`
3. **Find working sample** — `microsoft_code_sample_search(query: "[task]", language: "[lang]")`

For simple lookups, step 1 alone may suffice. Always verify when:
- Method name seems "too convenient" (`UploadFile` vs actual `Upload`)
- Mixing SDK versions (v11 `CloudBlobClient` vs v12 `BlobServiceClient`)
- Package name doesn't follow conventions (`Azure.*` for .NET, `azure-*` for Python)
- Using an API for the first time

### Error Troubleshooting

| Error Type | Query |
|------------|-------|
| Method not found | `"[ClassName] methods [Namespace]"` |
| Type not found | `"[TypeName] NuGet package namespace"` |
| Wrong signature | `"[ClassName] [MethodName] overloads"` → fetch full page |
| Deprecated warning | `"[OldType] migration v12"` |
| Auth failure | `"DefaultAzureCredential troubleshooting"` |
| 403 Forbidden | `"[ServiceName] RBAC permissions"` |

---

## Exceptions: When to Use Other Tools

The following categories live **outside** learn.microsoft.com.

### .NET Aspire — Use Aspire MCP Server or Context7

Aspire docs live on **aspire.dev**, not Learn.

| MCP Tool | Description |
|----------|-------------|
| `list_docs` | Lists all available documentation from aspire.dev |
| `search_docs` | Weighted lexical search across aspire.dev content |
| `get_doc` | Retrieves a specific document by slug |

**Context7 fallback:**

| Library ID | Use for |
|---|---|
| `/microsoft/aspire.dev` | Guides, integrations, CLI reference, deployment |
| `/dotnet/aspire` | Runtime source — API internals |
| `/communitytoolkit/aspire` | Community integrations — Go, Java, Node.js, Ollama |

### VS Code — Use Context7

| Library ID | Use for |
|---|---|
| `/websites/code_visualstudio` | User docs — settings, features, debugging, remote dev |
| `/websites/code_visualstudio_api` | Extension API — webviews, TreeViews, commands |

### GitHub — Use Context7

| Library ID | Use for |
|---|---|
| `/websites/github_en` | Actions, API, repos, security, admin, Copilot |
| `/websites/cli_github` | GitHub CLI (`gh`) commands and flags |

### Context7 Setup

Resolve the library ID first (one-time per session):
1. Call `mcp_context7_resolve-library-id` with the technology name
2. Call `mcp_context7_query-docs` with the returned library ID and a specific query

---

## Writing Effective Queries

Be specific — include version, intent, and language:

```
# ❌ Too broad
"Azure Functions"

# ✅ Specific
"Azure Functions Python v2 programming model"
"Cosmos DB partition key design best practices"
"GitHub Actions workflow_dispatch inputs matrix strategy"
```

Include context:
- **Version** when relevant (`.NET 8`, `VS Code 1.96`)
- **Task intent** (`quickstart`, `tutorial`, `overview`, `limits`, `API reference`)
- **Language** for polyglot docs (`Python`, `TypeScript`, `C#`)
