# Workflow Inventory — All 11 GitHub Actions Workflows

Complete inventory of Undercurrent's GitHub Actions workflows with schedules, timeouts, and purposes.

---

## Workflow Table

| # | Workflow | File | Schedule | Timeout | Purpose |
|---|----------|------|----------|---------|---------|
| 1 | CI | `ci.yml` | push/PR to master | 15m | audit → lint → tsc → test → build |
| 2 | Congressional Scraper | `congressional-scraper.yml` | Hourly | 30m | Python Playwright for Senate eFD + House Clerk |
| 3 | Senate eFD | `senate-efd.yml` | Disabled | — | Akamai-blocked, kept for future retry |
| 4 | Stock Fundamentals | `stock-fundamentals.yml` | Every 6h | 20m | yahoo-finance2 quoteSummary for all tickers |
| 5 | Weekly Data Sources | `weekly-data-sources.yml` | Sun 04:00 UTC | 20m | openFDA, USPTO, USAspending, Senate LDA |
| 6 | Price History Backfill | `price-history-backfill.yml` | Sun 02:00 UTC | 20m | 365-day price history fill |
| 7 | Sentiment Rotation | `sentiment-rotation.yml` | 03:00/15:00 UTC | 20m | 4-day ticker rotation, 4 sources parallel |
| 8 | EDGAR Continuous | `edgar-continuous.yml` | Every 6h | 20m | EDGAR Form 4 + filing metadata |
| 9 | XBRL Background | `xbrl-background.yml` | Sun 03:00 UTC | 20m | XBRL financial data expansion |
| 10 | Percentile Refresh | `percentile-refresh.yml` | Daily 07:00 UTC | 20m | Full-universe percentile computation |
| 11 | Signal Analysis | `signal-analysis.yml` | Daily 08:30 UTC | 20m | 7 subcommands: predictions, outcomes, rarity, anomalies, regime, LR calibration, propagation |

---

## Schedule Conflict Map

```
Hour (UTC)   Workflows Running
00:00        Pipeline (Vercel, every 10 min — all hours)
02:00        Price History Backfill (Sun only)
03:00        Sentiment Rotation, XBRL Background (Sun only)
04:00        Weekly Data Sources (Sun only)
07:00        Percentile Refresh (daily)
08:00        Pipeline daily gates: FRED, CFTC, EIA, TSA
08:30        Signal Analysis (daily)
15:00        Sentiment Rotation
*:00         Congressional Scraper (hourly)
*:00,*:06... Stock Fundamentals, EDGAR Continuous (every 6h)
```

**Key timing rules**:
- Sentiment (03:00/15:00) avoids pipeline overlap at hours % 4 === 0
- Signal analysis (08:30) runs after pipeline daily gates (08:00) and percentile refresh (07:00)
- Weekly sources (Sun 04:00) avoid sentiment (03:00) and XBRL (03:00) by 1 hour
- Price history (Sun 02:00) runs before the Sunday batch (03:00-04:00)

---

## Common Configuration

All workflows share:
- `permissions: { contents: read }` — least privilege
- `actions/setup-node@v4` with `node-version-file: ".nvmrc"` + `cache: npm`
- `npm ci` for dependency installation (not `npm install`)
- Step/job `timeout-minutes` set explicitly

---

## 13F Institutional (Conditional)

Not listed in the main 11 because it's gated behind `ENABLE_13F=true`:
- File: `13f-institutional.yml`
- Schedule: Sun 08:00 UTC
- Purpose: 13F institutional holdings from 20 filers
- Only runs when `ENABLE_13F` env var is `true`

---

## Adding a New Workflow

Before adding a new scheduled workflow:
1. Check the conflict map above — avoid overlapping with existing schedules
2. Set `permissions: { contents: read }` at top level
3. Set `timeout-minutes` on every job
4. Include `workflow_dispatch` for manual triggering
5. Use `.nvmrc` for Node version (not hardcoded)
6. Document the schedule with a comment in the cron expression
7. Add the workflow to this inventory
