---
name: pipeline-change-checklist
description: This skill should be used before modifying the pipeline, sync-tickers, sentiment worker, or GitHub Actions in the Undercurrent project.
version: 0.1.0
---

# Pipeline Change Checklist

**TL;DR**: Budget formula + concurrency model + cadence gates + cleanup isolation.

1. **Vercel budget**: `num_companies × delay_per_request < 270s`. Current: PIPELINE_BATCH_SIZE=600, Yahoo batch=300, target ~200s. If new source exceeds → GitHub Actions, not Vercel.
2. **Concurrency**: use `pooled()`. Not raw `Promise.all`. Pools: Yahoo=4, EDGAR=2, fundamentals=5.
3. **Circuit breakers**: 5 failures → open, 30s reset. Don't change without documented reason.
4. **Cleanup isolation**: streak tracking, delisting zombies → own `try/catch`. Never share error fate with upstream fetch.
5. **Batch failure tracking**: failed Yahoo batches do NOT increment streak. Only successful batches with missing quotes.
6. **Cadence gates** (confirm before changing):
   - Daily 8 UTC: FRED, CFTC, EIA, TSA
   - Monthly 1st 8 UTC: French factors, betas
   - Sentiment: 03:00/15:00 UTC (avoids pipeline overlap)
