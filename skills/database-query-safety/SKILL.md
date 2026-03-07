---
name: database-query-safety
description: This skill should be used before writing any Supabase or PostgREST query in the Undercurrent project — 8 gotchas that cause silent failures.
version: 0.1.0
---

# Database Query Safety

**TL;DR**: 8 PostgREST gotchas. Check all before writing any query.

1. **No `.update().or().select()`** → read-then-write. Returns `data: null` silently.
2. **`.in()` chunk size** → `num_tickers × max_rows_per_ticker`. If > 40K, chunk to 100 tickers.
3. **Upsert: all NOT NULL columns required** → build Map from existing data, don't re-query.
4. **Two separate `max_rows` gotchas**:
   - Dashboard setting (50K) hard-caps regardless of `.limit()` in code
   - Code-level `.limit(50000)` still required to document intent
   - Both must be set — neither substitutes for the other
5. **No `.maybeSingle()` after `.update()`** → 406 Not Acceptable.
6. **Verify column names** → bad column = silent null + error object, no throw. With `Promise.allSettled` → `[]`.
7. **`ntile()` population** → run on deduplicated set, not raw ticker×date matrix.
8. **Re-query anti-pattern** → use Maps from initial query, never new `.in()` queries for NOT NULL column lookup.
