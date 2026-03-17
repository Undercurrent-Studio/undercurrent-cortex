# Migration Incidents — Real Failures Worth Learning From

5 incidents that shaped the migration safety rules. Each one caused real downtime or required a fix migration.

---

## 1. Partial Index with `now()` (3x Repeat Offender)

**Migrations affected**: Multiple across V1-V16
**Error**: `ERROR: 42P17: functions in index predicate must be marked IMMUTABLE`

**What happened**: Created a partial index `WHERE expires_at > now()`. PostgreSQL rejected it because `now()` is STABLE, not IMMUTABLE. This exact mistake was made 3 separate times across different sessions, making it the single most repeated migration error in the codebase.

**Fix**: Use trailing index column instead of `now()` in WHERE. The query planner still uses the index efficiently at runtime.

**Prevention**: Pre-commit gate checks for `now()` in WHERE clauses of migration files. Added to `tasks/lessons.md` with explicit pattern.

---

## 2. Lookup Table FK Violation

**Migration**: `NNN_lookup_table.sql`
**Error**: Foreign key constraint violation during seed data INSERT

**What happened**: Seed data included `INSERT INTO lookup_aliases (alias, canonical_code) VALUES ('OLD_CODE', 'NEW_CODE')` but the `entities` table didn't have code 'NEW_CODE' (it had been renamed). The FK violation rolled back the entire migration — including the CREATE TABLE and all policies.

**Fix**: Added `WHERE EXISTS (SELECT 1 FROM entities WHERE code = ...)` guard on all seed INSERT statements. Created a follow-up migration as an idempotent retry with the guard.

**Lesson**: Supabase migrations are fully transactional. A failed INSERT rolls back CREATE TABLE too.

---

## 3. Constraint Name Mismatch

**Migration**: `NNN_add_column.sql`
**Error**: `constraint "uq_reports_entity" for relation "reports" does not exist`

**What happened**: An earlier migration created a UNIQUE constraint on `reports(entity_id)`. The plan assumed the constraint was named `uq_reports_entity` (the explicit name used in the migration). But Supabase/Postgres auto-named it `reports_entity_id_key` using the default pattern. The `DROP CONSTRAINT` failed.

**Fix**: Created a follow-up migration with `DROP CONSTRAINT IF EXISTS` for BOTH names:
```sql
ALTER TABLE reports DROP CONSTRAINT IF EXISTS uq_reports_entity;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_entity_id_key;
```

**This was the 3rd constraint naming incident** across the project. Prevention: always verify production constraint names before writing DROP CONSTRAINT.

---

## 4. Event Tracking Seed Data FK Violation

**Migration**: `NNN_event_tracking.sql`
**Error**: FK violation on seed data referencing entities that don't exist

**What happened**: The migration included seed data for `events` that referenced entities via FK. Some entities didn't exist in the `entities` table (they had been removed between when the seed data was written and when the migration ran).

**Fix**: Added `WHERE EXISTS` guard on all FK-referencing INSERTs. The table logic itself was correct — only the seed data caused the failure.

**Lesson**: Seed data with FK constraints must always guard against missing references. The data state when you write the migration may differ from when it runs.

---

## 5. Transactional Rollback Surprise

**Context**: Early migration debugging
**Error**: Expected partial success, got full rollback

**What happened**: A migration had: CREATE TABLE → ALTER TABLE (add columns) → CREATE POLICY → INSERT seed data. The INSERT failed (NULL in NOT NULL column). Expected the table and columns to exist (they were created successfully), but the ENTIRE migration rolled back — no table, no columns, nothing.

**Fix**: The fix migration had to include ALL statements (CREATE TABLE, ALTER TABLE, CREATE POLICY, fixed INSERT), not just the corrected INSERT.

**Lesson**: Never assume partial success in Supabase migrations. If the last statement fails, the first statement's effects are also gone. Fix migrations must be complete and self-contained.
