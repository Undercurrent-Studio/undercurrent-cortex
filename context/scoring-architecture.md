# Scoring Architecture Context

V11 scoring engine: 5 pillars (Financial Health 25%, Growth & Momentum 25%, Smart Money 20%, Market Signals 20%, Catalysts 10%) with 43 sub-factors and peer-relative percentile ranking.

**Key files**: `src/lib/scoring/` — v10-engine.ts, v10-helpers.ts, v10-composite.ts, v10-pipeline.ts, percentile.ts, transfer-functions.ts, scoring-utils.ts.

**Scoring flow**: `scoreSubFactorV11()` routes factors through RAW_SCORE -> transfer function (sigmoid/log_sigmoid/piecewise) -> percentile. Null-excluded weight renormalization ensures missing data doesn't penalize scores. Coverage discount: pillar level (<50% factors -> penalty), composite level (<60% pillars -> penalty).

**Convergence amplifier**: [-6, 6] range. Negative for bearish-aligned convergence. Applied in `assembleComposite()`.

**Score weights**: Insider 33% + Congressional 33% + Sentiment 33% (stocks). ETFs/funds: 0/50/50.

**Signal Intelligence**: 13 signal detectors in `src/lib/signals/`. Bayesian P(bullish) via sequential log-odds update. 8D signal vector (tanh normalization). Exponential half-life decay. Pattern rarity, prediction tracking, regime detection, LR calibration, network propagation.
