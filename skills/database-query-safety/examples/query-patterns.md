# Query Patterns — Bad vs Good

8 common Supabase/PostgREST patterns with bad and good implementations.

---

### 1. Conditional Update

```ts
// BAD — .update().or().select() returns null
const { data } = await supabase
  .from("job_state")
  .update({ locked: true })
  .eq("id", 1)
  .or("locked.is.null,locked.eq.false")
  .select()
  .single();

// GOOD — read-then-write
const { data: state } = await supabase
  .from("job_state")
  .select("locked")
  .eq("id", 1)
  .single();
if (state?.locked) return "skipped";
await supabase.from("job_state").update({ locked: true }).eq("id", 1);
```

### 2. Bulk Upsert with NOT NULL Columns

```ts
// BAD — missing NOT NULL columns on upsert
await supabase.from("entities").upsert(
  tickers.map(t => ({ code: t, market_cap: caps.get(t) })),
  { onConflict: "code" }
);

// GOOD — include all NOT NULL columns from existing data
const nameMap = new Map(existing.map(e => [e.code, e.display_name]));
await supabase.from("entities").upsert(
  tickers.map(t => ({
    code: t,
    market_cap: caps.get(t),
    display_name: nameMap.get(t) ?? "Unknown",
  })),
  { onConflict: "code" }
);
```

### 3. Large `.in()` Query

```ts
// BAD — exceeds max_rows (600 × 365 = 219K > 50K)
const { data } = await supabase
  .from("daily_records")
  .select("*")
  .in("entity_id", allIds);

// GOOD — chunk to stay under limit
const CHUNK = 100; // 100 × 365 = 36,500 < 50K
const results: RecordRow[] = [];
for (let i = 0; i < ids.length; i += CHUNK) {
  const { data } = await supabase
    .from("daily_records")
    .select("*")
    .in("entity_id", ids.slice(i, i + CHUNK));
  if (data) results.push(...data);
}
```

### 4. Null-Safe Column Rendering

```ts
// BAD — crashes on null
const formatted = row.metric_value.toFixed(2);

// GOOD — null guard
const formatted = row.metric_value != null
  ? row.metric_value.toFixed(2)
  : "-";
```

### 5. Cache Function Error Handling

```ts
// BAD — caches null on error (stale for entire TTL)
async function getScores() {
  "use cache";
  const { data, error } = await adminClient
    .from("metrics")
    .select("*");
  return data; // null on error — cached as null
}

// GOOD — throw on error (never cache failures)
async function getScores() {
  "use cache";
  const { data, error } = await adminClient
    .from("metrics")
    .select("*");
  if (error) throw new Error(`metrics: ${error.message}`);
  return data;
}
```

### 6. Percentile on Deduplicated Set

```sql
-- BAD — ntile on raw ticker×date matrix
SELECT ticker, score, ntile(5) OVER (ORDER BY score DESC) AS quintile
FROM metric_snapshots;

-- GOOD — deduplicate first, then ntile
WITH latest AS (
  SELECT DISTINCT ON (ticker) ticker, score
  FROM metric_snapshots
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
  .from("metrics")
  .select("ticker, composit_score"); // should be composite_score

// GOOD — verify columns exist, check for error
const { data, error } = await supabase
  .from("metrics")
  .select("ticker, composite_score");
if (error) throw new Error(`Query error: ${error.message}`);
```

### 8. Batch Upsert Utility

```ts
// BAD — single INSERT of 5000 rows
await supabase.from("daily_prices").insert(allRows);

// GOOD — use a batch upsert utility (500-row chunks, count verification)
await batchUpsert(adminClient, "daily_prices", allRows, "entity_id,record_date");
```
