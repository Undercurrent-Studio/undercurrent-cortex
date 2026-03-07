---
name: data-integrity
description: This skill should be used when the user asks to "display data", "add a chart", "show a number", "create a data component", "fix wrong data", "debug null values", "add a pipeline source", "handle data freshness", "fix stale cache", or before any code that displays, transforms, or stores financial data in the Undercurrent project. Enforces 'every number must be accurate and traceable.'
version: 0.1.0
---

# Data Integrity

**TL;DR**: Every number must be accurate and traceable. 10 rules for displaying, transforming, and storing financial data.

## The 10 Rules

### 1. Source Traceability
Every number displayed in the UI must trace to a specific database table and column. When adding a data display, document the chain: `source API → ingestion function → DB table.column → cached loader → component prop`.

### 2. Null Handling
Never display `null`, `undefined`, `NaN`, or empty strings as data values.
- Use `formatDollar(val)` for currency (returns `"-"` for null)
- Use `formatCompact(val)` for large numbers
- Use `val ?? "-"` as the minimum fallback
- Column renderers: type ALL non-PK fields as `T | null` and null-guard before calling `.toFixed()`, `.replace()`, etc.

### 3. Failure Modes
Pipeline failures must never corrupt or lose existing data.
- Circuit breakers per source (5 failures → open, 30s timeout)
- Upsert on natural keys (update existing, never duplicate)
- Failed batches tracked separately — never increment `no_quote_streak` for tickers in failed batches
- Graceful degradation: if one source fails, others continue. Never all-or-nothing.

### 4. Cache Correctness
- `'use cache'` functions must throw on Supabase errors — never cache `null` results
- Cache tags must be rotated to bust stale cached errors
- Pro/Free tier included in shared cache keys (prevent cross-tier data leakage)
- Cache TTL should match or be shorter than pipeline cadence — see `revalidate` values in cached-loader functions

### 5. Free/Pro Gating
Tier check happens at data fetch time, not after fetching all data and filtering client-side.
- Server-side enforcement in API routes and cached loaders
- Constants from `src/lib/constants.ts` — never hardcode limits
- Free users see teaser (blurred/limited), not empty state
- Note: Gating philosophy overlaps with `product-identity` skill. See `references/free-pro-matrix.md` for the complete matrix.

### 6. Type Discipline
- **BIGINT** + `Math.round()` / `int()` at ingestion boundary for: dollar amounts, volume, share counts (whole), market cap
- **NUMERIC** for: EPS, ratios, per-share values, percentages, weighted average share counts (fractional)
- Yahoo Finance returns all numbers as floats — round BIGINT-bound values at ingestion
- XBRL share counts are fractional (weighted averages) — use NUMERIC, not BIGINT

### 7. Data Freshness
- Display "as of" timestamps where data staleness matters (prices, sentiment)
- Pipeline health tracked in `data_source_health` table
- Stale data (>24h for daily sources) should show visual warning [aspirational — not yet in UI; `data_source_health` tracks freshness server-side]
- Score performance cache refreshed every 10 min by pipeline

### 8. Aggregation Correctness
- Null-excluded averages: when averaging scores or metrics, exclude nulls from both sum and count (not null=0)
- Weighted averages where appropriate (e.g., recency-weighted sentiment)
- Coverage discount: if <50% of sub-factors have data, apply pillar coverage discount
- Composite discount: if <60% of pillars have data, apply composite coverage discount

### 9. Unit Consistency
Always display:
- Currency symbol (`$`) on dollar amounts
- Percentage sign (`%`) on percentages
- Multiplier suffix (`K`/`M`/`B`/`T`) on large numbers via `formatCompact()`
- Sign prefix (`+`/`-`) on changes via `formatSignedColor()`
- Consistent decimal precision within a column (e.g., all EPS to 2 decimals)

### 10. Deduplication
- Upsert on natural keys (ticker + date, ticker + source, etc.) — never blind INSERT
- `batchUpsert()` from `src/lib/utils/batch-upsert.ts` handles 500-row chunks with count verification
- Unique constraints in migrations enforce dedup at DB level
- Pipeline re-runs must be idempotent — same input produces same output

## Quick Reference: Common Gotchas

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| `formatDollar(null)` | Displays "$NaN" | Function handles null → returns `"-"` |
| PostgREST bad column in `.select()` | Returns `null` data + error (no throw) | Verify column names against schema |
| `.in()` query exceeds max_rows | Silently truncated results | Chunk queries (100 tickers per chunk) |
| Yahoo batch failure | Mass false delistings | Track failed batch tickers, exclude from streak |
| Cache null result | Stale error cached for TTL | Throw inside `'use cache'` functions |

See `references/data-source-map.md` for the full source inventory.
