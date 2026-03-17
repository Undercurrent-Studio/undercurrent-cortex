# Data Source Map — Template

Document every external data source your project consumes. This inventory is your single source of truth for understanding data flow, debugging pipeline issues, and onboarding new contributors.

## Source Inventory

### Example: Price API
- **API**: REST (API key, rate limited)
- **Data**: Batch quotes, market cap, fundamentals, price history
- **Ingestion**: `fetchPriceQuotes()` → `entities` + `daily_prices` + `entity_fundamentals`
- **Pipeline stage**: Every run (prices = all entities, fundamentals = current batch)
- **Cadence**: 10-min cron + 6h background job
- **Quirks**: Returns all numbers as floats (round integer-bound values at ingestion). Batch failures can cause false delistings if not tracked.

### Example: Government Filing API
- **API**: REST (no auth, User-Agent header, 10 req/sec)
- **Data**: Regulatory filings, financial statements, institutional holdings
- **Ingestion**: `fetchFilings()` → `regulatory_filings`, `fetchFinancials()` → `financial_data`
- **Pipeline stage**: Current batch every run. Full financials weekly.
- **Cadence**: 10-min pipeline + weekly background job
- **Quirks**: Some documents have format prefixes that return HTML instead of raw data — strip prefixes before parsing. Foreign entities may use different reporting standards.

### Example: Sentiment Aggregator
- **API**: Public feed (no auth) + REST APIs (API key)
- **Data**: Social sentiment scores, news tone, search interest, page views
- **Ingestion**: `fetchSentiment()` → `sentiment_snapshots`
- **Pipeline stage**: Sentiment phase (every 4h)
- **Cadence**: 4h cron + 2x daily background job
- **Quirks**: Minimum sample thresholds for valid scores. Short entity names cause false positives.

---

## Pipeline Architecture Summary

| Environment | Sources | Cadence | Max Runtime |
|-------------|---------|---------|-------------|
| Serverless cron | Real-time data (prices, filings) | Every N min | Function timeout |
| Serverless cron | Periodic data (sentiment, macro) | Every N hours | Function timeout |
| Background jobs | Slow/heavy sources (financials, filings) | Daily/weekly | Long-running (hours) |

## Error Handling

- **Concurrency**: Work-stealing pool with per-source concurrency limits
- **Circuit breakers**: Per source, N consecutive failures → open (cooldown period)
- **Streak tracking**: Track consecutive failures per entity to detect stale/delisted entries
- **Health logging**: All source successes/failures written to a health tracking table
- **Isolation**: `Promise.allSettled` per source — one failure doesn't abort others
- **Timeouts**: Per-source timeout prevents a single slow source from blocking the pipeline
