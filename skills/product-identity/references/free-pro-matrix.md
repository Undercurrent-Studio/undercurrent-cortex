# Free vs Pro Gating Matrix

## Constants (from `src/lib/constants.ts`)

| Constant | Value | Description |
|----------|-------|-------------|
| `FREE_WATCHLIST_LIMIT` | 3 | Max watchlist stocks for free users |
| `FREE_STOCK_LIMIT` | 500 | Max stocks visible in screener (top by market cap) |
| `FREE_INSIDER_LIMIT` | 10 | Insider transactions shown per stock |
| `FREE_CONGRESSIONAL_LIMIT` | 5 | Congressional trades shown per stock |
| `FREE_ALERT_RULE_LIMIT` | 3 | Custom alert rules for free users |
| `PRO_ALERT_RULE_LIMIT` | 25 | Custom alert rules for Pro users |
| `FREE_DAILY_ALERT_CAP` | 10 | Max alerts fired per day (free) |
| `PRO_DAILY_ALERT_CAP` | 50 | Max alerts fired per day (Pro) |
| `ENABLE_AI_BRIEFS` | true | Global kill switch for AI brief generation |

## Gating Strategy: Depth, Not Access

| Feature | Free | Pro |
|---------|------|-----|
| **Stock universe** | Top 500 by market cap | Full ~6K stocks |
| **Watchlist** | 3 stocks | Unlimited |
| **Price charts** | 7-day history | Full history |
| **Insider transactions** | 10 per stock | Full history |
| **Congressional trades** | 5 per stock | Full history |
| **Sentiment** | Composite only | Per-source breakdown |
| **AI briefs** | Cached (shared) | On-demand (fresh) |
| **Thesis narratives** | Evidence only | Full AI narrative |
| **Daily Briefing** | Not available | Full page |
| **CFTC data** | Not available | Full access |
| **Database explorer** | Not available | 14-tab full access |
| **Custom alert rules** | 3 rules, 10/day | 25 rules, 50/day |
| **Scoring** | Composite score | Full pillar breakdown |
| **Signal Stack** | Visible | Visible |
| **P(bullish)** | Visible | Visible |
| **Screener** | Top 500 | Full universe + filters |
| **Portfolio tracking** | Not available | Full |

## Gating Implementation Rules

1. **Tier check happens at data fetch time** — not after fetching all data and filtering client-side
2. **Pro features show a teaser to free users** — blurred content or "Upgrade to Pro" overlay, never completely hidden
3. **Constants live in `src/lib/constants.ts`** — never hardcode limits in components
4. **Cache keys include tier** — `shared` cache for public data, `private` cache for user-scoped data with tier in key
5. **Server-side enforcement** — never rely on client-side gating alone. API routes verify tier before returning data.

## Pricing

- **Pro**: $30/month (Stripe subscription)
- **Free**: No credit card required, no trial expiration
- **Entity**: Undercurrent Studio L.L.C.
