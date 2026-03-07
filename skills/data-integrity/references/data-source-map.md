# Data Source Map

All 18 sources are free. Total API cost: $0/month.

## Source Inventory

### Yahoo Finance
- **API**: `yahoo-finance2` npm package (unofficial, no auth)
- **Data**: Batch quotes, market cap, fundamentals (~55 cols), fund fundamentals, earnings estimates, price history (365d)
- **Ingestion**: `fetchYahooQuotes()` → `stocks` + `stock_prices` + `stock_fundamentals`
- **Pipeline stage**: Every run (Yahoo prices = all tickers, fundamentals = current batch)
- **Cadence**: 10-min pipeline + 6h GitHub Actions (stock-fundamentals)
- **Quirks**: Returns all numbers as floats (round BIGINT-bound values). Batch failures cause mass false delistings if not tracked. `avg_volume` goes to `stocks` table (not `stock_fundamentals`). `quoteSummary` modules need `as never` cast.

### SEC EDGAR
- **API**: REST API (no auth, User-Agent header, 10 req/sec)
- **Data**: Form 4 insider filings (multi-owner, gift txns filtered), Form 144 pre-sale notices, filing metadata, XBRL financials (110 metrics + 7 JSONB dimensional), 13F institutional holdings
- **Ingestion**: `fetchEdgarForm4()` → `insider_transactions`, `fetchXBRLData()` → `sec_financials`, `fetch13FHoldings()` → `institutional_holdings`
- **Pipeline stage**: SEC EDGAR = current batch every run. XBRL = weekly (Sun 03 UTC). 13F = weekly (Sun 08 UTC, gated by `ENABLE_13F`)
- **Quirks**: `primaryDocument` has XSLT prefix (strip it). Foreign filers (ADRs) have no `us-gaap` namespace. Companies switch XBRL concept names over time — merge ALL variants. XML parsed with `fast-xml-parser`.

### Finnhub
- **API**: REST (API key, 60 req/min free)
- **Data**: Social sentiment scores
- **Ingestion**: `fetchFinnhubSentiment()` → `sentiment_snapshots`
- **Pipeline stage**: Sentiment (every 4h) + sentiment-worker (2x daily)
- **Quirks**: Congressional trading endpoint is premium-only (disabled). Min 3 tagged messages for StockTwits.

### Senate eFD + House Clerk
- **API**: Playwright browser scraper (Senate) + curl_cffi (House PDFs)
- **Data**: Congressional trade disclosures (PTR filings)
- **Ingestion**: Python scraper → `congressional_trades`
- **Pipeline stage**: GitHub Actions (hourly)
- **Quirks**: Senate eFD protected by Akamai Bot Manager (AJAX endpoint returns 503). Current workaround: GitHub Actions scraper. House PDFs parsed with pdfplumber.

### GDELT
- **API**: REST (no auth, unlimited)
- **Data**: Global news sentiment/tone scoring
- **Ingestion**: `fetchGDELTSentiment()` → `sentiment_snapshots`
- **Pipeline stage**: Sentiment (every 4h) + sentiment-worker
- **Quirks**: 5 concurrent workers, 1s delay, ~8s timeout. In 12-min source timeout: ~720 tickers.

### Google Trends
- **API**: `google-trends-api` npm (unofficial, no auth)
- **Data**: Consumer search interest (relative)
- **Ingestion**: `fetchGoogleTrends()` → `sentiment_snapshots`
- **Pipeline stage**: Sentiment (every 4h) + sentiment-worker
- **Quirks**: Skips 1-letter tickers (too ambiguous). False positives for short ticker symbols are a fundamental limitation.

### Wikipedia Pageviews
- **API**: REST (no auth, generous limits)
- **Data**: Daily page view counts (retail attention proxy)
- **Ingestion**: `fetchWikipediaPageviews()` → `sentiment_snapshots`
- **Pipeline stage**: Sentiment (every 4h) + sentiment-worker

### StockTwits
- **API**: Public feed (no auth needed)
- **Data**: 30 recent messages per ticker with bull/bear tags
- **Ingestion**: `fetchStockTwitsSentiment()` → `sentiment_snapshots`
- **Pipeline stage**: Sentiment (every 4h) + sentiment-worker
- **Quirks**: Minimum 3 tagged messages required for a valid score.

### FRED (Federal Reserve Economic Data)
- **API**: REST (API key, 120 req/min free)
- **Data**: 16 economic indicators (VIX, yields, DGS3MO, DGS10, crude, gold, GDP, CPI, FX rates)
- **Ingestion**: `fetchFREDData()` → `macro_indicators`
- **Pipeline stage**: Daily at 8 UTC (cadence gate)
- **Quirks**: DCF uses DGS10 (long-term rate). Sharpe ratio uses DGS3MO (short-term rate).

### CFTC (Commitments of Traders)
- **API**: Socrata/SODA (no auth, unlimited)
- **Data**: COT positioning (S&P 500, Nasdaq-100, Russell 2000 futures)
- **Ingestion**: `fetchCFTCData()` → `cftc_positioning`
- **Pipeline stage**: Daily at 8 UTC (cadence gate)
- **Quirks**: Pro-only feature. `$limit=500` on Socrata queries.

### US EIA (Energy Information Administration)
- **API**: REST (API key, 1000 req/hr free)
- **Data**: Crude inventories, natural gas, WTI prices, electricity
- **Ingestion**: `fetchEIAData()` → `macro_indicators`
- **Pipeline stage**: Daily at 8 UTC
- **Quirks**: Circuit breaker protected. Errors logged to `data_source_health`.

### TSA (Transportation Security Administration)
- **API**: Web scraping (no auth)
- **Data**: Airport passenger throughput (current + prior year)
- **Ingestion**: `fetchTSAData()` → `macro_indicators`
- **Pipeline stage**: Daily at 8 UTC
- **Quirks**: Circuit breaker protected. Errors logged to `data_source_health`.

### Kenneth French Data Library
- **API**: CSV files (no auth, unlimited)
- **Data**: Fama-French 5 factors + momentum (daily returns)
- **Ingestion**: `fetchFrenchFactors()` → `french_factors`
- **Pipeline stage**: Monthly (1st at 8 UTC, cadence gate)

### openFDA
- **API**: REST (no auth, 240 req/min)
- **Data**: Drug & device enforcement events (recalls, warnings)
- **Ingestion**: `fetchFDAEvents()` → `gov_regulatory`
- **Pipeline stage**: Weekly (GitHub Actions)

### USPTO PatentsView
- **API**: REST (no auth, generous)
- **Data**: Patent grant counts by assignee (12-month windows)
- **Ingestion**: `fetchPatentData()` → `gov_regulatory`
- **Pipeline stage**: Weekly (GitHub Actions)

### USAspending.gov
- **API**: REST (no auth, generous)
- **Data**: Federal government contract awards by recipient
- **Ingestion**: `fetchUSASpendingData()` → `gov_regulatory`
- **Pipeline stage**: Weekly (GitHub Actions)

### Senate LDA (Lobbying Disclosure Act)
- **API**: REST (no auth, generous)
- **Data**: Lobbying disclosure filings by client/registrant
- **Ingestion**: `fetchLobbyingData()` → `gov_regulatory`
- **Pipeline stage**: Weekly (GitHub Actions)

## Pipeline Architecture Summary

| Environment | Sources | Cadence | Max Runtime |
|-------------|---------|---------|-------------|
| Vercel cron (10 min) | Yahoo, SEC EDGAR, scoring | Every 10 min | 270s (300s limit) |
| Vercel cron (4h) | Sentiment (Finnhub, GDELT, Trends, Wiki, StockTwits) | Every 4 hours | 270s |
| Vercel cron (daily) | FRED, CFTC, EIA, TSA | Daily 8 UTC | 270s |
| GitHub Actions | Congressional, fundamentals, XBRL, 13F, sentiment-worker, price-history, signal-analysis | Various | 6h max |
| GitHub Actions (monthly) | French factors, betas | 1st of month | 6h max |

## Error Handling

### Pipeline Sources (Vercel cron)
- **Concurrency**: `pooled()` work-stealing pool — Yahoo 4, EDGAR 2, fundamentals 5 concurrent workers
- **Circuit breakers**: Per source, 5 consecutive failures → open (30s cooldown). Config in `src/lib/utils/circuit-breaker.ts`
- **Streak tracking**: `no_quote_streak` on `stocks` table. Failed batch tickers excluded from streak increment
- **Health logging**: All source successes/failures written to `data_source_health` table via `src/lib/utils/source-health.ts`

### GitHub Actions Sources
- **Isolation**: `Promise.allSettled` per source — one failure doesn't abort others
- **Timeouts**: 12-min per-source timeout via `withTimeout()` in sentiment-worker
- **Retry**: No automatic retry within a single run. Schedule cadence provides implicit retry (hourly for congressional, 2x daily for sentiment, weekly for XBRL/13F)
