# Migration Lessons Context

**IMMUTABLE trap (3x repeat offender)**: PostgreSQL partial indexes require IMMUTABLE functions in WHERE clause. `now()`, `CURRENT_DATE`, `clock_timestamp()` are ALL non-IMMUTABLE. Use materialized columns or remove time conditions from WHERE. The migration-linter hook blocks this automatically.

**Transactional rollback**: Supabase wraps each migration in a transaction. ANY failure rolls back EVERYTHING — including CREATE TABLE, ALTER TABLE, policies. Fix migrations must recreate all statements, not just the "missing" part.

**Idempotency**: Always use `IF NOT EXISTS` for CREATE, `DROP ... IF EXISTS` for modifications. Always include RLS + policies + GRANT on new tables: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` + `CREATE POLICY` + `GRANT SELECT ON ... TO authenticated, service_role;`

**Constraint naming**: PostgreSQL auto-names constraints differently from explicit names (`{table}_{column}_key` for UNIQUE, `{table}_{column}_fkey` for FK). Always verify production names via Supabase dashboard before writing DROP CONSTRAINT.

**PostgREST upsert**: Requires ALL NOT NULL columns even for existing rows — PostgreSQL checks constraints on INSERT path BEFORE evaluating ON CONFLICT.

**Data types**: BIGINT + `Math.round()` for whole-number values (dollars, volume, counts). NUMERIC for decimals (EPS, ratios, percentages, share counts).
