---
name: scoring-change-checklist
description: This skill should be used when adding, removing, or modifying scoring sub-factors, changing pillar weights, adjusting transfer function parameters, modifying percentile computation, changing the convergence amplifier, debugging unexpected score values, or making any change to files in src/lib/scoring/ in the Undercurrent project.
version: 0.1.0
---

# Scoring Change Checklist

**TL;DR**: 10 items to verify before touching the V11 scoring engine. The scoring system has 43 sub-factors across 5 pillars — changes have non-obvious downstream effects.

## The 10 Items

### 1. V11 Architecture Map

5 pillars with 43 sub-factors. Key files:

| File | Purpose |
|------|---------|
| `src/lib/scoring/v10-engine.ts` | Pillar computation, `scoreSubFactorV11()` |
| `src/lib/scoring/v10-helpers.ts` | Data collection for scoring |
| `src/lib/scoring/v10-composite.ts` | Composite score + convergence amplifier |
| `src/lib/scoring/v10-pipeline.ts` | Pipeline orchestration |
| `src/lib/scoring/percentile.ts` | Percentile computation + storage |
| `src/lib/scoring/transfer-functions.ts` | 19 transfer function definitions |
| `src/lib/scoring/scoring-utils.ts` | Shared scoring utilities |
| `src/lib/constants.ts` | SCORE_WEIGHTS, pillar weight maps |

Read the relevant file(s) BEFORE making changes. Cite line numbers.

### 2. Sub-Factor Routing

`scoreSubFactorV11()` routes each factor through one of two paths:
- **Transfer function path**: factor has a registered transfer function → applies sigmoid/log_sigmoid/piecewise → 0-100
- **Percentile path**: factor has NO transfer function → peer-relative percentile → 0-100

**Never add a factor to BOTH paths.** Check `transfer-functions.ts` for existing registrations before adding new factors.

**Choosing a path**: Use transfer functions for metrics with known distributions and meaningful absolute thresholds (e.g., profit margins, growth rates). Use percentile scoring for metrics that only make sense relative to peers (e.g., sector-specific ratios).

### 3. Transfer Function Calibration

Transfer functions use calibrated parameters:
- `midpoint` ≈ p50 of the factor distribution
- `steepness` tuned so p90 → score ~85

If `config.invert = true`, the transfer function handles its own inversion. Inverted factors must NOT also appear in `INVERTED_SUB_FACTORS` — that would double-invert.

### 4. Null-Excluded Renormalization

When a sub-factor has no data (null), it is excluded entirely — the remaining sub-factor weights are renormalized to 1.0. This means:
- Missing data is NOT penalized as score=0
- A stock with 3 of 5 sub-factors still gets a meaningful pillar score
- Coverage discount applies when too few sub-factors have data (<50% pillar, <60% composite)

**Never change null handling without understanding the renormalization math.**

### 5. Weight Changes

Weights live in `src/lib/constants.ts`:
- `SCORE_WEIGHTS` — top-level pillar weights
- Per-pillar weight maps — sub-factor weights within each pillar

**CLAUDE.md guardrail**: The old scoring used Insider 33% + Congressional 33% + Sentiment 33%. V11 uses a 5-pillar architecture with different weights. If changing weights, update both `constants.ts` AND `documentation.md`.

### 6. Convergence Amplifier

Bearish convergence amplifier range: [-6, 6]. Lives in `v10-composite.ts`. Applied AFTER pillar scoring, BEFORE final composite clamping.

Changes to the amplifier range or logic affect the final composite score nonlinearly. A small range change can shift hundreds of stock scores.

### 7. Percentile Computation

Full-universe percentile refresh via `computeAndStorePercentiles()`:
- Pipeline: runs in `run-pipeline` route, extracted before signal detection
- Daily: GitHub Actions `percentile-refresh.yml` at 07:00 UTC
- Stores sector + global breakpoints in `percentile_stats` table
- Uses `mean` and `stddev` columns for anomaly scoring

**Before changing percentile logic**: verify the pipeline flow order — percentiles must be computed BEFORE signal detection uses them.

### 8. Signal Integration

Pipeline flow: `collectV10Data()` → `fetchSectorMap()` + `computeAndStorePercentiles()` → `detectSignalEvents()` → `enrichWithPatternHash()` → `logSignalEvents()` → `scoreFromCollectedData()` → Step 5: Bayesian.

Bayesian posterior (`p_bullish`) and signal columns (`signal_confidence`, `signal_entropy`, `active_signal_count`) are written separately from V11 pillar scores. **Don't conflate signal scoring with V11 pillar scoring** — they are independent systems that both write to `undercurrent_scores`.

### 9. Test Coverage

Scoring changes MUST include tests:
- `v10-engine.test.ts` — pillar computation
- `transfer-functions.test.ts` — transfer function correctness
- `percentile.test.ts` — percentile computation
- `v10-composite.test.ts` — composite + convergence

Run `npm test -- --run` and verify no regressions. If adding a new sub-factor, add test cases for: normal value, null value, extreme value, inverted factor (if applicable).

### 10. Documentation Sync

After any scoring change:
1. Update `documentation.md` scoring section with new weights, factors, or architecture changes
2. Update MEMORY.md auto-memory if the change is structural
3. If weight definitions change, verify CLAUDE.md guardrail is still accurate

See `references/scoring-architecture.md` for the full V11 architecture reference.
