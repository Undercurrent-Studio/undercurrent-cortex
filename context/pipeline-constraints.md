# Pipeline Constraints Context

**Runtime budget**: Vercel Pro 300s max. Pipeline targets ~200s (33% headroom). Single cron `/api/cron/run-pipeline` every 10 min. Time-based branching determines which tasks execute.

**Concurrency**: `pooled()` work-stealing pool (Yahoo 4, EDGAR 2, fundamentals 5 concurrent workers). Circuit breakers per source (5 failures -> open, 30s timeout). Streak tracking for source health.

**Batching**: `PIPELINE_BATCH_SIZE=600` tickers/run. Yahoo prices fetches ALL tickers. SEC EDGAR processes current batch only. Sentiment + scoring every 4h.

**Cadence gates**: Daily sources (FRED/CFTC/EIA/TSA) run at 8 UTC. Monthly sources (French factors + betas) run 1st of month 8 UTC.

**Error isolation**: Independent cleanup steps must NOT share try/catch with fallible operations. If operation B doesn't depend on A's result, they should not share error fate.

**Serverless limits**: Sequential API calls exceeding 300s must be offloaded to GitHub Actions (6h max runtime). Current offloaded: stock fundamentals, sentiment rotation, EDGAR continuous, XBRL background, price history backfill, signal analysis.

**Key utilities**: `company_name_map` + `normalizeCompanyName()` for external source name->ticker resolution. `batchUpsert()` for 500-row chunked writes with count verification.
