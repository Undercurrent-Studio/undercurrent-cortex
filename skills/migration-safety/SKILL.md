---
name: migration-safety
description: This skill should be used when writing, reviewing, or fixing a Supabase migration, creating a new database table, adding columns or indexes, writing seed data with foreign keys, or debugging a migration that failed or rolled back in the Undercurrent project. Covers IMMUTABLE constraints, transactional rollback, RLS+policies+grants, IF NOT EXISTS patterns, constraint naming, and data type discipline.
version: 0.1.0
---

# Migration Safety

**TL;DR**: 8 rules that prevent migration failures. Every one has caused a real incident in this codebase.

## The 8 Rules

### 1. IMMUTABLE Constraint (3x Repeat Offender)

`now()`, `CURRENT_DATE`, and `clock_timestamp()` are **NOT IMMUTABLE**. They are STABLE (return different values across transactions). PostgreSQL requires all functions in partial index WHERE clauses to be IMMUTABLE.

**Never**: `CREATE INDEX ... WHERE expires_at > now()`
**Instead**: Include the time column as a trailing index column:
```sql
CREATE INDEX idx_foo ON tbl(col1, col2, expires_at);
```
The query planner still uses the index efficiently when queries filter `WHERE expires_at > now()` at runtime.

### 2. Transactional Rollback

Supabase wraps each migration file in a transaction. If ANY statement fails (an INSERT with a FK violation, a constraint error), the **ENTIRE migration rolls back** — including CREATE TABLE, ALTER TABLE, CREATE POLICY, everything.

**Implication**: Fix migrations must include ALL statements from the original (table creation, RLS, policies, seed data), not just the "missing" part. You cannot rely on partial success.

### 3. Constraint Naming

PostgreSQL auto-names constraints differently from explicit names. A migration may specify `uq_ai_briefs_ticker` but production may have `ai_briefs_ticker_key` (Postgres default pattern: `{table}_{column}_key` for UNIQUE, `{table}_{column}_fkey` for FK).

**Always**: Use dual-name IF EXISTS:
```sql
ALTER TABLE ai_briefs DROP CONSTRAINT IF EXISTS uq_ai_briefs_ticker;
ALTER TABLE ai_briefs DROP CONSTRAINT IF EXISTS ai_briefs_ticker_key;
```

**Before writing**: Check actual production constraint names via Supabase dashboard or `\d+ tablename`.

### 4. IF NOT EXISTS Patterns

Always use defensive patterns to prevent "already exists" failures on re-run or fix migrations:
- `CREATE TABLE IF NOT EXISTS`
- `CREATE INDEX IF NOT EXISTS`
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` (PostgreSQL 11+)
- `DO $$ BEGIN ... EXCEPTION WHEN duplicate_object THEN NULL; END $$;` for policies and constraints:
```sql
DO $$ BEGIN
  ALTER TABLE tbl ADD CONSTRAINT uq_foo UNIQUE (col);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

### 5. RLS + Policies + Grants

Every new table needs all three:
```sql
ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read" ON new_table
  FOR SELECT TO authenticated USING (true);

GRANT SELECT ON new_table TO authenticated;
```

Missing any one of these causes silent failures — RLS without policies = no rows returned, policies without GRANT = permission denied.

### 6. Seed Data FK Safety

INSERT statements with foreign key constraints must guard against missing references:
```sql
INSERT INTO ticker_aliases (alias, canonical_ticker)
SELECT 'FB', 'META'
WHERE EXISTS (SELECT 1 FROM stocks WHERE ticker = 'META');
```

Without the guard, a FK violation rolls back the entire migration (Rule 2).

### 7. Data Type Discipline

Match the ingestion boundary:
- **BIGINT** + `Math.round()` / `int()` for: dollar amounts, volume, share counts (whole), market cap
- **NUMERIC** for: EPS, ratios, per-share values, percentages, weighted average share counts (fractional)
- Yahoo Finance returns all numbers as floats — round BIGINT-bound values at the ingestion boundary
- XBRL share counts are fractional (weighted averages) — use NUMERIC, not BIGINT

### 8. Testing Migrations

- Run `supabase db reset` locally before pushing to verify the full migration chain
- Test rollback by intentionally introducing a failure — verify the entire migration rolls back cleanly
- After applying to production, verify with a quick SELECT that tables/columns/indexes exist as expected
- If a migration fails in production, write a NEW fix migration (don't edit the failed one) with ALL statements from the original plus corrections

See `references/migration-incidents.md` for 5 real incidents from this codebase.
