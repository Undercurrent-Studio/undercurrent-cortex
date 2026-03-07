# Query Patterns — Bad vs Good

8 common Supabase/PostgREST patterns with bad and good implementations.

---

### 1. Conditional Update

```ts
// BAD — .update().or().select() returns null
const { data } = await supabase
  .from("pipeline_state")
  .update({ locked: true })
  .eq("id", 1)
  .or("locked.is.null,locked.eq.false")
  .select()
  .single();

// GOOD — read-then-write
const { data: state } = await supabase
  .from("pipeline_state")
  .select("locked")
  .eq("id", 1)
  .single();
if (state?.locked) return "skipped";
await supabase.from("pipeline_state").update({ locked: true }).eq("id", 1);
```

### 2. Bulk Upsert with NOT NULL Columns

```ts
// BAD — missing NOT NULL columns on upsert
await supabase.from("stocks").upsert(
  tickers.map(t => ({ ticker: t, market_cap: caps.get(t) })),
  { onConflict: "ticker" }
);

// GOOD — include all NOT NULL columns from existing data
const nameMap = new Map(existingStocks.map(s => [s.ticker, s.company_name]));
await supabase.from("stocks").upsert(
  tickers.map(t => ({
    ticker: t,
    market_cap: caps.get(t),
    company_name: nameMap.get(t) ?? "Unknown",
  })),
  { onConflict: "ticker" }
);
```

### 3. Large `.in()` Query

```ts
// BAD — exceeds max_rows (600 × 365 = 219K > 50K)
const { data } = await supabase
  .from("price_history")
  .select("*")
  .in("ticker", allTickers);

// GOOD — chunk to stay under limit
const CHUNK = 100; // 100 × 365 = 36,500 < 50K
const results: PriceRow[] = [];
for (let i = 0; i < tickers.length; i += CHUNK) {
  const { data } = await supabase
    .from("price_history")
    .select("*")
    .in("ticker", tickers.slice(i, i + CHUNK));
  if (data) results.push(...data);
}
```

### 4. Null-Safe Column Rendering

```ts
// BAD — crashes on null
const formatted = row.earnings_per_share.toFixed(2);

// GOOD — null guard
const formatted = row.earnings_per_share != null
  ? row.earnings_per_share.toFixed(2)
  : "-";
```

### 5. Cache Function Error Handling

```ts
// BAD — caches null on error (stale for entire TTL)
async function getScores() {
  "use cache";
  const { data, error } = await adminClient
    .from("scores")
    .select("*");
  return data; // null on error — cached as null
}

// GOOD — throw on error (never cache failures)
async function getScores() {
  "use cache";
  const { data, error } = await adminClient
    .from("scores")
    .select("*");
  if (error) throw new Error(`scores: ${error.message}`);
  return data;
}
```

### 6. Percentile on Deduplicated Set

```sql
-- BAD — ntile on raw ticker×date matrix
SELECT ticker, score, ntile(5) OVER (ORDER BY score DESC) AS quintile
FROM score_daily_snapshots;

-- GOOD — deduplicate first, then ntile
WITH latest AS (
  SELECT DISTINCT ON (ticker) ticker, score
  FROM score_daily_snapshots
  ORDER BY ticker, snapshot_date DESC
),
ranked AS (
  SELECT *, ntile(5) OVER (ORDER BY score DESC) AS quintile
  FROM latest
)
SELECT * FROM ranked;
```

### 7. Column Name Verification

```ts
// BAD — typo silently returns null (no throw)
const { data } = await supabase
  .from("scores")
  .select("ticker, composit_score"); // should be composite_score

// GOOD — verify columns exist, check for error
const { data, error } = await supabase
  .from("scores")
  .select("ticker, composite_score");
if (error) throw new Error(`Query error: ${error.message}`);
```

### 8. Batch Upsert Utility

```ts
// BAD — single INSERT of 5000 rows
await supabase.from("stock_prices").insert(allRows);

// GOOD — use batchUpsert (500-row chunks, count verification)
import { batchUpsert } from "@/lib/utils/batch-upsert";
await batchUpsert(adminClient, "stock_prices", allRows, "ticker,price_date");
```
