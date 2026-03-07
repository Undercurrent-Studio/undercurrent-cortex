# V11 Scoring Architecture Reference

Complete reference for the V11 scoring engine. Read this before modifying any scoring code.

---

## Pipeline Flow

```
collectV10Data()           — fetch all raw data for the batch
    ↓
fetchSectorMap()           — sector assignments for peer grouping
    ↓
computeAndStorePercentiles() — full-universe percentile breakpoints
    ↓
detectSignalEvents()       — 13 signal detectors
    ↓
enrichWithPatternHash()    — pattern rarity hashing
    ↓
logSignalEvents()          — write to signal_events table
    ↓
scoreFromCollectedData()   — V11 pillar scoring per ticker
    ↓
Step 5: Bayesian           — P(bullish) from signal events (independent)
```

Percentiles MUST be computed before signal detection (anomaly scoring needs sector stats).
V11 scoring and Bayesian P(bullish) are independent — both write to `undercurrent_scores`.

---

## 5 Pillars

| Pillar | Weight | Sub-Factors | Key Data |
|--------|--------|-------------|----------|
| Financial Health | 25% | ~10 (profitability, leverage, liquidity, efficiency) | XBRL financials, stock_fundamentals |
| Growth & Momentum | 25% | ~10 (revenue growth, earnings surprise, price momentum) | XBRL, Yahoo, price_history |
| Smart Money | 20% | ~8 (insider buys/sells, congressional trades, 13F) | SEC Form 4, congressional_trades, institutional_holdings |
| Market Signals | 20% | ~8 (sentiment, short interest, options, volatility) | Finnhub, StockTwits, GDELT, Google Trends |
| Catalysts | 10% | ~7 (earnings date, FDA, patents, government contracts) | Yahoo, openFDA, USPTO, USAspending |

Sub-factor counts are approximate — see `v10-engine.ts` for the definitive list.

---

## Scoring Flow Per Sub-Factor

```
Raw value (from collected data)
    ↓
Clamp to reasonable bounds (prevent outlier distortion)
    ↓
Has transfer function registered?
    ├── YES → Apply transfer function (sigmoid/log_sigmoid/piecewise) → 0-100 score
    └── NO  → Peer-relative percentile scoring → 0-100 score
    ↓
If factor is inverted (lower = better): score = 100 - score
    ↓
Per-factor score (0-100)
```

### Transfer Function Types

| Type | Shape | Use When |
|------|-------|----------|
| `sigmoid` | S-curve with midpoint + steepness | Most continuous metrics (margins, growth rates) |
| `log_sigmoid` | S-curve on log-transformed input | Skewed distributions (dollar volumes, market cap) |
| `piecewise` | Custom breakpoints | Categorical or non-continuous metrics |

19 factors currently have transfer functions. All others use percentile scoring.

---

## Composite Computation

```
Per-pillar scores (5 values, 0-100 each)
    ↓
Coverage discount:
  - If pillar has <50% sub-factors with data → apply coverage discount
  - If composite has <60% pillars with data → apply composite discount
    ↓
Weighted average of pillar scores (using SCORE_WEIGHTS from constants.ts)
    ↓
Convergence amplifier:
  - Range: [-6, 6]
  - Applied additively to composite
  - Bearish convergence increases amplifier (negative direction)
  - Bullish convergence increases amplifier (positive direction)
    ↓
Clamp to [0, 100]
    ↓
Final composite score
```

---

## Score Labels

| Range | Label |
|-------|-------|
| 68+ | Strong |
| 52-67 | Moderate |
| 35-51 | Neutral |
| <35 | Weak |

---

## Key Constants (from `src/lib/constants.ts`)

- `SCORE_WEIGHTS` — pillar weight map
- `V10_MIN_SUB_FACTORS = 5` — minimum sub-factors for a valid score
- `CONVERGENCE_AMPLIFIER_RANGE = [-6, 6]`
- `PILLAR_COVERAGE_THRESHOLD = 0.5` — 50% minimum for pillar
- `COMPOSITE_COVERAGE_THRESHOLD = 0.6` — 60% minimum for composite

---

## Related Systems (Independent)

- **Bayesian P(bullish)**: `src/lib/signals/bayesian.ts` — sequential log-odds update from signal events. Writes `p_bullish`, `signal_confidence`, `signal_entropy` to scores. NOT part of V11 pillar scoring.
- **Signal Intelligence**: 13 detectors in `src/lib/signals/` — writes to `signal_events`. Feeds Bayesian, not V11.
- **Score Performance Cache**: `compute_score_performance()` SQL function → `score_performance_cache` table. Pipeline refreshes every 10 min.
