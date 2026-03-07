# Pipeline Constraints Reference

Hard limits and architectural constraints governing the Undercurrent data pipeline.

---

## 1. Vercel Budget

**Hard limit**: 300s (Vercel Pro plan `maxDuration`).
**Safe target**: 270s (30s buffer for cold starts, response serialization).
**Budget formula**: `num_companies × delay_per_request < 270s`

Current configuration:
- `PIPELINE_BATCH_SIZE = 600` (from `src/lib/constants.ts`)
- Yahoo batch size = 300 (2 batches per pipeline run)
- Target runtime: ~200s (33% headroom)

**When to offload to GitHub Actions**: If a new data source requires `num_companies × delay_per_request > 270s` (e.g., USPTO: 200 companies × 2 calls × 1.5s = 500s), move it to a GitHub Actions workflow with up to 6h runtime. Keep fast real-time sources on Vercel.

**`canStartPhase()` limitation**: The guard checks elapsed time at phase START, not during execution. A phase that starts at t=5s can still run for 500s+ and exceed the function limit. Budget planning must account for worst-case phase duration, not just start time.

---

## 2. `pooled()` Concurrency

Work-stealing pool pattern from `src/lib/utils/pooled.ts`. Replaces raw `Promise.all` for external API calls.

**Defined pools** (tuned to API rate limits):
| Pool | Concurrency | Used For |
|------|-------------|----------|
| Yahoo | 4 | Quote batches, fundamentals |
| EDGAR | 2 | Form 4, filings, XBRL |
| Fundamentals | 5 | Yahoo quoteSummary |

**Rules**:
- Never use raw `Promise.all()` for external APIs — always `pooled()`
- Pool sizes match rate limits of the upstream API
- Each pool call gets its own circuit breaker check
- Failed tasks don't block the pool — work-stealing continues with remaining items

---

## 3. Cadence Gates

Time-based branching in the pipeline route determines which tasks execute on each 10-minute cron tick.

**Daily gates** (8:00 UTC):
- FRED (16 macro series)
- CFTC (COT positioning)
- EIA (4 energy series)
- TSA (throughput)

**Monthly gates** (1st of month, 8:00 UTC):
- Kenneth French factors (6 factor files)
- Stock betas (regression against market)

**Sentiment worker** (separate from pipeline):
- Schedule: 03:00 / 15:00 UTC
- Avoids pipeline overlap (pipeline runs at hours % 4 === 0)
- 4-day ticker rotation (2000 tickers per slice)
- 4 sources in parallel via `Promise.allSettled`
- Per-source 12-min timeout via `withTimeout()`

**GitHub Actions schedules**:
- Fundamentals: every 6h
- EDGAR: every 6h
- Congressional scraper: hourly
- Sentiment rotation: 03:00/15:00 UTC
- Weekly sources (openFDA, USPTO, USAspending, LDA): Sunday
- Price history backfill: Sunday 02:00 UTC
- XBRL: Sunday 03:00 UTC (changed from daily)
- 13F institutional: Sunday 08:00 UTC (gated by ENABLE_13F)
- Percentile refresh: daily 07:00 UTC
- Signal analysis: daily 08:30 UTC

**Before changing any schedule**: verify no overlap with existing schedules above. Sentiment (03:00/15:00) and signal analysis (08:30) were specifically timed to avoid collisions.

---

## 4. Circuit Breakers

Per-source circuit breakers protect the pipeline from cascading failures.

**Configuration**:
- Threshold: 5 consecutive failures → circuit opens
- Reset timeout: 30s
- Tracked in `data_source_health` table

**Rules**:
- Each data source has its own circuit breaker
- Open circuits skip the source entirely (graceful degradation)
- Failed batch tickers tracked separately — never increment `no_quote_streak` for tickers in failed batches (prevents mass false delistings)
- Cleanup steps (delisting, streak tracking) in their own `try/catch` — never share error fate with upstream fetch

**Yahoo batch failure protection**: When a Yahoo batch of 300 tickers fails entirely, all 300 are added to `failedBatchTickers`. These are excluded from streak increment. Only tickers in successful batches that returned no quote get streak incremented. Without this, a single failed batch can delist 300+ stocks (including AAPL).

---

## 5. Batch Sizing

**Pipeline batch**: `PIPELINE_BATCH_SIZE = 600` from `src/lib/constants.ts`
- Controls how many tickers are processed per pipeline run
- Yahoo quotes all tickers; EDGAR processes current batch only
- `fullseed` mode caps at 3000 tickers

**`.in()` query sizing**: Calculate worst-case before writing any `.in()` query:
- Formula: `num_tickers × max_rows_per_ticker < max_rows (50000)`
- Price history: 100 tickers per chunk (100 × 365 = 36,500 < 50K)
- Scores/fundamentals: safe at 600 (1 row per ticker)
- Sentiment snapshots: chunk to 500 (multiple snapshots per ticker)

**`batchUpsert()` sizing**: 500 rows per chunk (from `src/lib/utils/batch-upsert.ts`). Count verification after each chunk. All pipeline writes should use this utility.
