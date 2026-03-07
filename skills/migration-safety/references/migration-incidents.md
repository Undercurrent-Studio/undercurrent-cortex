# Migration Incidents — Real Failures from the Undercurrent Codebase

5 incidents that shaped the migration safety rules. Each one caused real downtime or required a fix migration.

---

## 1. Partial Index with `now()` (3x Repeat Offender)

**Migrations affected**: Multiple across V1-V16
**Error**: `ERROR: 42P17: functions in index predicate must be marked IMMUTABLE`

**What happened**: Created a partial index `WHERE expires_at > now()`. PostgreSQL rejected it because `now()` is STABLE, not IMMUTABLE. This exact mistake was made 3 separate times across different sessions, making it the single most repeated migration error in the codebase.

**Fix**: Use trailing index column instead of `now()` in WHERE. The query planner still uses the index efficiently at runtime.

**Prevention**: Pre-commit gate checks for `now()` in WHERE clauses of migration files. Added to `tasks/lessons.md` with explicit pattern.

---

## 2. Migration 055 — Ticker Aliases FK Violation

**Migration**: `055_ticker_aliases.sql`
**Error**: Foreign key constraint violation during seed data INSERT

**What happened**: Seed data included `INSERT INTO ticker_aliases (alias, canonical_ticker) VALUES ('TWTR', 'X')` but the `stocks` table didn't have ticker 'X' (it had been renamed). The FK violation rolled back the entire migration — including the CREATE TABLE and all policies.

**Fix**: Added `WHERE EXISTS (SELECT 1 FROM stocks WHERE ticker = ...)` guard on all seed INSERT statements. Created migration 056 as an idempotent retry with the guard.

**Lesson**: Supabase migrations are fully transactional. A failed INSERT rolls back CREATE TABLE too.

---

## 3. Migration 063 — Constraint Name Mismatch

**Migration**: `063_ai_briefs_brief_type.sql`
**Error**: `constraint "uq_ai_briefs_ticker" for relation "ai_briefs" does not exist`

**What happened**: The original migration (022) created a UNIQUE constraint on `ai_briefs(ticker)`. The plan assumed the constraint was named `uq_ai_briefs_ticker` (the explicit name used in the migration). But Supabase/Postgres auto-named it `ai_briefs_ticker_key` using the default pattern. The `DROP CONSTRAINT` failed.

**Fix**: Created migration 064 as an idempotent retry with `DROP CONSTRAINT IF EXISTS` for BOTH names:
```sql
ALTER TABLE ai_briefs DROP CONSTRAINT IF EXISTS uq_ai_briefs_ticker;
ALTER TABLE ai_briefs DROP CONSTRAINT IF EXISTS ai_briefs_ticker_key;
```

**This was the 3rd constraint naming incident** (055 FK, 063 UNIQUE, plus earlier partial index naming). Prevention: always verify production constraint names before writing DROP CONSTRAINT.

---

## 4. Migration 052 — Convergence Atomic Upsert

**Migration**: `052_convergence_atomic_upsert.sql`
**Error**: FK violation on seed data referencing stocks that don't exist

**What happened**: The migration included seed data for `convergence_events` that referenced tickers via FK. Some tickers didn't exist in the `stocks` table (they had been delisted between when the seed data was written and when the migration ran).

**Fix**: Added `WHERE EXISTS` guard on all FK-referencing INSERTs. The atomic upsert logic itself was correct — only the seed data caused the failure.

**Lesson**: Seed data with FK constraints must always guard against missing references. The data state when you write the migration may differ from when it runs.

---

## 5. Transactional Rollback Surprise

**Context**: Early migration debugging
**Error**: Expected partial success, got full rollback

**What happened**: A migration had: CREATE TABLE → ALTER TABLE (add columns) → CREATE POLICY → INSERT seed data. The INSERT failed (NULL in NOT NULL column). Expected the table and columns to exist (they were created successfully), but the ENTIRE migration rolled back — no table, no columns, nothing.

**Fix**: The fix migration had to include ALL statements (CREATE TABLE, ALTER TABLE, CREATE POLICY, fixed INSERT), not just the corrected INSERT.

**Lesson**: Never assume partial success in Supabase migrations. If the last statement fails, the first statement's effects are also gone. Fix migrations must be complete and self-contained.
