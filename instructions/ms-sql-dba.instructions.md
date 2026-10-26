---
applyTo: '**/*.sql'
description: '**CRITICAL**: Read this file BEFORE writing or editing ANY .sql file. Contains mandatory DRY_RUN convention for data-modifying scripts, ASCII-only encoding rules, and schema verification requirements.'
---

# SQL File Standards

## Database Access Rules

Configure database connection profiles in your local environment (see your project's README for connection details).

**Access tier summary:**
- **Local**: Full CRUD. Always prefer local — scrubbed/restored prod data if available.
- **Dev**: Full CRUD with user confirmation before writes.
- **Test**: Read-only. Generate scripts for writes, ask user to run manually.
- **Remote read replica**: Read-only. Use when local/dev data isn't sufficient.
- **Production primary**: **NEVER connect.** No reads, no writes, no connections.

## Schema Verification Before Generating SQL

Before writing any SQL that references table columns (SELECT, INSERT, UPDATE, DELETE, JOIN), **verify the schema first**. Do not guess column names, types, or constraints.

**Verification order** (use the first available):
1. **MSSQL MCP tools** (if connected) — run `mssql_list_tables` to see columns and types. This is the most accurate source.
2. **Entity classes in the codebase** — search for the corresponding C# entity class (e.g., `PartyRoleStatus.cs`, `PhoneNumber.cs`). These are T4-generated from the database and reflect the current schema.
3. **Existing SQL scripts in the repo** — look at other scripts that reference the same tables for column name patterns.
4. **Ask the user** — if none of the above are available, ask which columns exist before generating.

**Never assume**:
- Column names (e.g., `UpdatedOn` vs `ModifiedOn` vs `UpdateDate`)
- Nullable vs non-nullable columns
- Whether audit columns (`CreatePartyId`, `UpdatePartyId`, `CreatedOn`, `UpdatedOn`) exist on a table
- Foreign key relationships — verify JOINs against actual schema

## Encoding: ASCII-Only in Executable SQL

SQL Server `PRINT` and string expressions use `varchar` by default, which cannot render Unicode characters like emojis or em-dashes. **All executable SQL strings must be ASCII-only.**

- **PRINT statements**: No emojis (⚠️, ✅, ⬅️), no em-dashes (—). Use `--` or `-` instead of `—`, and plain text markers like `[WARNING]`, `[OK]`, `[DONE]` instead of emojis.
- **CASE/string expressions**: Same rule — ASCII-only in any computed string value.
- **Comments** (`--` and `/* */`): Emojis and Unicode are fine — SQL Server doesn't execute comments.

```sql
-- Bad (encoding error at runtime)
PRINT '⚠️  DRY RUN MODE — No data changes were made.';

-- Good
PRINT '[DRY RUN] No data changes were made. Set @DRY_RUN = 0 to execute.';
```

## Dry-Run Convention for Data-Modifying Scripts

Any SQL script that contains UPDATE, DELETE, INSERT, or MERGE statements **must** include a centralized `@DRY_RUN` flag that defaults to safe mode (`1`). The script must never modify data unless the user manually changes the flag to `0`.

**Required pattern**:

```sql
-- ============================================================================
-- CRITICAL: CENTRALIZED DRY RUN FLAG - CHANGE THIS ONE VALUE ONLY
-- ============================================================================
-- @DRY_RUN = 1 (DEFAULT): Shows analysis only, NO DATA CHANGES
-- @DRY_RUN = 0: EXECUTES the modifications
-- ============================================================================
DECLARE @DRY_RUN BIT = 1;  -- << CHANGE THIS VALUE ONLY (1 = dry run, 0 = execute)
-- ============================================================================
```

**Rules**:
- `@DRY_RUN` is always `1` by default — never generate a script with `0`
- Each step checks `@DRY_RUN`: dry run shows a preview (SELECT with sample data), execute mode runs the actual modification inside a transaction
- Include a verification query at the end to confirm the results
- All PRINT messages must use ASCII-only text (no emojis, no em-dashes)
- This applies to all SQL scripts — work projects, personal projects, one-off queries, everything
