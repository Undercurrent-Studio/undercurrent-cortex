# Plan Audit Checklist — 12 Items Across 3 Tiers

Run this checklist before presenting any implementation plan for approval. Write `## Plan Self-Audit` at the bottom of the plan file with pass/fail + evidence for each item.

**Tier 1/2 failures = fix the plan before proceeding.**
**Tier 3 failures = flagged, don't hard-block if user accepts the tradeoff.**

---

## Tier 1: Codebase Accuracy

*Did I actually verify what I'm building on?*

### 1. Read every file to modify
Did I `Read` (not grep) every file I plan to modify? Cite line numbers for the specific code being changed.

**Failure example**: Feature plan assumed `EntityData` had 6 field names without reading the type definition — all 6 were wrong.

### 2. Data types, signatures, and interfaces match
Do the function signatures, column types, and interface shapes I assumed actually match the codebase? Cite the specific lines.

**Failure example**: Query used `event_date` column — correct column is `detected_at`. A previous audit found a widget was completely dead from this.

### 3. Existing utilities checked
Did I check for existing utilities, patterns, and abstractions before proposing new ones? Name what I found or confirmed doesn't exist.

**Failure example**: Multiple pipeline modules independently implemented batch chunking logic. A shared batch-upsert utility already existed.

### 4. File paths verified
Are all file paths verified to exist (or explicitly marked as `[NEW]`)? No phantom paths.

**Failure example**: Plan referenced a scoring engine file that had already been replaced by a newer version.

---

## Tier 2: Constraint Compliance

*Does the plan respect the platform's hard limits?*

### 5. Pipeline budget
Does the plan respect the Vercel 270s budget? Formula: `num_tickers x delay_per_request < 270s`. If new source exceeds, has it been moved to GitHub Actions?

**Failure example**: New data source (200 entities x 2 calls x 1.5s = 500s) was planned for the serverless pipeline. Exceeded 300s limit. Had to be moved to a weekly background job.

### 6. PostgREST query safety
Are all `.in()` queries sized correctly? (`num_tickers x max_rows_per_ticker < max_rows`). Are all `.select()` column names verified? No `.update().or().select()` patterns?

**Failure example**: History backfill with BATCH_SIZE=600 produced `.in()` queries returning 219K rows, silently truncated at 50K.

### 7. Middleware and auth coverage
If adding new routes under `(dashboard)/`, is the middleware matcher updated? If adding API routes, is CRON_SECRET or auth verified?

**Failure example**: A dashboard route was missing from the middleware matcher — session tokens not refreshed, expired JWTs caused empty pages via RLS.

### 8. Env var three-way sync
If adding new env vars: listed for `src/lib/env.ts` + Vercel dashboard + GitHub Secrets? If new cron schedule: checked for collisions with existing schedules?

**Failure example**: Environment validation validates all server env vars eagerly. A missing API key for a non-critical source crashed the checkout route.

---

## Tier 3: Architectural Integrity

*Is the plan well-structured?*

### 9. Scope check
Does the plan touch only what was asked? If extras are proposed, are they flagged as optional?

### 10. Waves independently shippable
If Wave 5 fails, can Waves 1-4 deploy safely? Each wave must leave the system in a working state.

**Failure example**: This plugin's Wave 2 had a race condition — parallel PostToolUse hooks writing the same state file. Fixed with single dispatcher scripts.

### 11. Dependency ordering
Wave X never references something first built in Wave Y where Y > X. No forward dependencies.

**Failure example**: A migration's seed data referenced entities via FK that didn't exist in the parent table.

### 12. Test expectations
Are test expectations included for every wave? What tests, approximately how many, what they cover?

---

## How to Write the Self-Audit

At the bottom of your plan file:

```markdown
## Plan Self-Audit

### Tier 1: Codebase Accuracy
1. Read every file — PASS (read v10-engine.ts:1-450, constants.ts:1-80)
2. Types match — PASS (ScoreRow interface at v10-engine.ts:23 has all referenced fields)
3. Existing utilities — PASS (confirmed batchUpsert exists, no equivalent for X)
4. File paths — PASS (3 existing + 2 [NEW])

### Tier 2: Constraint Compliance
5. Pipeline budget — PASS (new source adds ~5s per batch, total ~205s)
6. PostgREST safety — PASS (no .in() queries, 3 .select() columns verified)
7. Middleware — N/A (no new routes)
8. Env vars — PASS (no new env vars)

### Tier 3: Architectural Integrity
9. Scope — PASS (3 files touched, all within task scope)
10. Waves shippable — PASS (Wave 1 standalone, Wave 2 builds on 1)
11. Dependencies — PASS (no forward refs)
12. Tests — PASS (Wave 1: 15 unit tests, Wave 2: 8 integration tests)
```
