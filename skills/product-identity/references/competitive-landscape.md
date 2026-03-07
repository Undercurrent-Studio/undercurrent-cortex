# Competitive Landscape

## The Benchmark: Bloomberg Terminal

- **What it does right**: Maximum information density. Keyboard-driven navigation. Real-time data from hundreds of sources. Trusted by every institutional desk globally.
- **What it costs**: ~$24,000/year per seat. Locked to proprietary hardware.
- **Undercurrent's angle**: Bloomberg's density and seriousness without the price tag. Free tier exposes raw data that Bloomberg locks behind a paywall. Signal intelligence layer provides analytical depth that Bloomberg doesn't offer in its default views. See `documentation.md` § Signal Intelligence for current capabilities.

## Closest Competitor: Koyfin

- **What it does right**: Free tier with substantial data access. Clean, modern UI with data density. Multiple chart types, screening, and comparison tools. $35-99/mo Pro plans.
- **Where it falls short**: No signal intelligence or conviction scoring. No insider/congressional trade analysis. No convergence detection. Dashboard is visual but not signal-forward.
- **Undercurrent's angle**: Deeper signal layer (multi-source detectors, Bayesian inference, prediction tracking). Congressional + insider trade analysis that Koyfin lacks entirely. Thesis generation grounded in quantitative signals. Free tier shows ALL data types (Koyfin gates some categories).

## Research Workflow: Sentieo (now AlphaSense)

- **What it does right**: Document search across filings, transcripts, news. Natural language queries over financial documents. Annotation and collaboration tools.
- **Where it falls short**: Expensive ($1,000+/mo). Document-centric rather than signal-centric. No real-time sentiment aggregation or scoring.
- **Undercurrent's angle**: Not competing on document search — competing on signal aggregation and pattern detection from structured public data sources. Undercurrent surfaces patterns across 18+ sources that Sentieo's document-focused approach misses.

## Other Competitors

| Platform | Strength | Gap Undercurrent Fills |
|----------|----------|----------------------|
| TradingView | Charts, social | No insider/congressional, no signal scoring |
| Finviz | Screening, heatmaps | No signal intelligence, stale fundamental data |
| Simply Wall St | Visual fundamentals | No insider signals, limited free tier |
| Quiver Quantitative | Congressional data | Single-source, no convergence/scoring |
| OpenInsider | Insider transactions | Raw data only, no analytical layer |

## Undercurrent's Unique Position

1. **Free data layer**: All 18+ source types visible to free users (depth-gated, not category-gated)
2. **Signal intelligence**: Multi-source signal detectors, Bayesian posterior, convergence detection, regime analysis, prediction tracking — no competitor offers this combination (see `documentation.md` for current detector count)
3. **Multi-source convergence**: Cross-referencing insider + congressional + sentiment + fundamentals + options to find signal agreement patterns
4. **Thesis generation**: Quantitative evidence assembled into structured investment theses with AI narrative
5. **Institutional data density**: Bloomberg-grade information packaging at consumer pricing ($30/mo)

## Design Implications

When building features, ask:
- Does this match the density and seriousness of Bloomberg? (not the complexity — the respect for the user's expertise)
- Does this provide analytical depth beyond what Koyfin offers for free?
- Is the signal-to-noise ratio high enough for a professional to trust this in their workflow?
- Would a portfolio manager keep this tab open alongside their Bloomberg terminal?
