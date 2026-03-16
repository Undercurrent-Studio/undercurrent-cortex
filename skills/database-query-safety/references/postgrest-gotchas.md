# PostgREST Gotchas — Symptoms, Root Causes, and Fixes

8 gotchas that cause silent data loss or corruption in Supabase/PostgREST queries. Each one has bitten this codebase at least once.

---

## 1. `.update().or().select()` Returns Empty

**Symptom**: The UPDATE executes successfully (data changes in DB), but `data` comes back as `null` or `[]`. Code thinks the operation failed. In the pipeline, this caused the lock to silently fail on every cron run — the lock was acquired but the code returned "skipped."

**Root cause**: PostgREST response parsing fails when conditional WHERE clauses (`.or()`) are combined with `.update().select()`. The rows are updated but the SELECT portion returns nothing.

**Bad**:
```ts
const { data } = await supabase
  .from("pipeline_state")
  .update({ locked: true })
  .eq("id", 1)
  .or("locked.is.null,locked.eq.false")
  .select()
  .single();
// data is null even though UPDATE worked
```

**Good**:
```ts
// Read first
const { data: state } = await supabase
  .from("pipeline_state")
  .select("locked")
  .eq("id", 1)
  .single();
if (state?.locked) return "skipped";
// Then write
await supabase.from("pipeline_state").update({ locked: true }).eq("id", 1);
```

---

## 2. `.maybeSingle()` After `.update()`

**Symptom**: 406 Not Acceptable error from PostgREST.

**Root cause**: PostgREST content negotiation rejects `.maybeSingle()` on UPDATE responses. The server expects the client to accept multiple rows but `.maybeSingle()` requests singular.

**Bad**: `.update({ col: val }).eq("id", 1).maybeSingle()`

**Good**: Use read-then-write (Gotcha 1), or `.update().eq("id", 1).select().single()` if you genuinely need the updated row back (rare).

---

## 3. Bad Column in `.select()` — Silent Null

**Symptom**: `data` is `null`, `error` object is present, but no exception is thrown. With `Promise.allSettled`, the result is `{ status: "fulfilled", value: { data: null, error: {...} } }` — code downstream receives an empty array.

**Root cause**: PostgREST sets an error header and returns a 200 with `null` data for unknown columns. The Supabase JS client does NOT throw — it returns the error as a property.

**Bad**:
```ts
const { data } = await supabase
  .from("scores")
  .select("ticker, nonexistent_column")  // typo or renamed column
// data is null, no throw — downstream gets []
```

**Good**: Always verify column names against the actual schema before writing queries. After any migration that renames/drops columns, grep for old column names in all `.select()` calls.

---

## 4. `.in()` Query Exceeds `max_rows`

**Symptom**: Query returns exactly `max_rows` results (e.g., 1000 or 50000) with no error. Data appears complete but is silently truncated. Price history backfill broke when PIPELINE_BATCH_SIZE increased from 300 to 600 — `600 × 365 = 219,000 rows > 50,000 max_rows`.

**Root cause**: Supabase has a project-level `max_rows` setting (default: 1000, project setting: 50000) that hard-caps ALL query results. Even explicit `.limit(50000)` can't exceed it. When `.in("ticker", tickers)` returns `tickers × rows_per_ticker`, the total easily exceeds the cap.

**Bad**: `.in("ticker", all6000Tickers).limit(50000)` — truncated at 50K.

**Good**: Calculate worst-case: `num_tickers × max_rows_per_ticker`. Chunk to stay under limit:
```ts
const CHUNK_SIZE = 100; // 100 × 365 = 36,500 < 50,000
for (let i = 0; i < tickers.length; i += CHUNK_SIZE) {
  const chunk = tickers.slice(i, i + CHUNK_SIZE);
  const { data } = await supabase.from("price_history").select("*").in("ticker", chunk);
}
```

---

## 5. Upsert Requires ALL NOT NULL Columns

**Symptom**: `null value in column "company_name" of relation "stocks" violates not-null constraint` — even though the row already exists and `company_name` is already set.

**Root cause**: PostgreSQL checks NOT NULL constraints on the INSERT path BEFORE evaluating the ON CONFLICT clause. The upsert payload must include every NOT NULL column, even for rows that will hit the UPDATE path.

**Bad**:
```ts
await supabase.from("stocks").upsert(
  [{ ticker: "AAPL", market_cap: 3e12 }],
  { onConflict: "ticker" }
); // Fails: company_name is NOT NULL
```

**Good**:
```ts
const nameMap = new Map(existingStocks.map(s => [s.ticker, s.company_name]));
await supabase.from("stocks").upsert(
  [{ ticker: "AAPL", market_cap: 3e12, company_name: nameMap.get("AAPL")! }],
  { onConflict: "ticker" }
);
```

---

## 6. `max_rows` Dashboard Setting — Two Layers

**Symptom**: Queries return exactly 1000 rows regardless of `.limit()` in code.

**Root cause**: Two independent caps exist — (1) Supabase Dashboard → Settings → API → Max Rows (project-level PostgREST setting), and (2) code-level `.limit()`. Both must be set. Neither substitutes for the other.

**Fix**: Set dashboard max_rows to 50000. Add `.limit(50000)` in code to document intent. For queries expected to return >50K rows, use chunking (Gotcha 4).

---

## 7. `ntile()` on Wrong Population

**Symptom**: Skewed quintile distribution in scatter charts — some quintiles have 5× more dots than others.

**Root cause**: `ntile(5) OVER (ORDER BY score DESC)` applied to a `ticker × date` matrix (96K rows) assigns quintiles per-row, not per-ticker. When deduplicating to one dot per ticker via `DISTINCT ON`, the distribution is uneven.

**Good**: Two-CTE approach — first CTE deduplicates (`DISTINCT ON (ticker)`), second CTE runs `ntile(5)` on the deduplicated set. Guarantees even 20/20/20/20/20 distribution.

---

## 8. Re-Query Anti-Pattern

**Symptom**: Unnecessary DB round-trips, risk of exceeding max_rows, slower pipeline runs.

**Root cause**: Making new `.in()` queries to look up data (like `company_name`) that was already fetched in a prior query. Each new query risks truncation and adds latency.

**Good**: Build Maps from initial query results:
```ts
const nameMap = new Map(stocks.map(s => [s.ticker, s.company_name]));
// Use nameMap.get(ticker) instead of querying again
```

Never make a new `.in()` query for NOT NULL column lookup — use the data you already have.
