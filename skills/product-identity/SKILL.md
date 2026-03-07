---
name: product-identity
description: This skill should be used when the user asks to "design a feature", "build a new component", "plan a page", "add functionality", or before any product decision in the Undercurrent project. Encodes the product mission, quality bar, and design principles that every feature must satisfy.
version: 0.1.0
---

# Product Identity

**TL;DR**: Undercurrent is an institutional-grade stock research platform. Every feature must pass the professional analyst test.

## Mission

Stock research data aggregation platform that surfaces hidden and correlated signals from 18+ free public data sources. Data-forward UX: all raw data visible free, Pro unlocks depth. Not a data viewer — a research TOOL for maximum depth and signal discovery.

**Target user**: Professional analysts, portfolio managers, and serious retail investors who want Bloomberg-grade data density without the Bloomberg price tag.

## Design Principles

1. **Performance** — Sub-second page loads. Efficient queries with proper indexing. No unnecessary re-renders. Lazy load heavy components. Data should feel instant.
2. **Data Integrity** — Every number displayed must be accurate and traceable to its source. Pipeline failures must never corrupt or lose data. Graceful degradation per source.
3. **UX Density** — Professionals want information density, not whitespace. Pack data intelligently — scannable tables, inline sparklines, contextual tooltips. Every pixel earns its place.
4. **Reliability** — The platform works flawlessly at 3am with zero human intervention. Circuit breakers, retry logic, atomic operations, proper error boundaries.
5. **Feature Completeness** — Never ship half-built features. If a section exists, it is fully functional with proper loading states, empty states, error states, and edge case handling.
6. **Polish** — Consistent spacing, alignment, color usage. No orphaned UI elements. Transitions and micro-interactions where they add clarity. The product should feel inevitable, not cobbled together.

## Free vs Pro Philosophy

Raw data is free — gating is on **depth**, not on **access**:
- Free users see the same data types as Pro — just fewer stocks, shorter history, fewer watchlist slots
- Pro unlocks: full universe (~6K stocks), full history, unlimited watchlist, per-source sentiment, CFTC, database explorer, on-demand AI briefs, Daily Briefing, thesis narratives
- Never paywall a data category entirely — always show enough to demonstrate value

See `references/free-pro-matrix.md` for the complete gating matrix with constants.

## Anti-Patterns (Never Do These)

- Whitespace-heavy layouts with sparse data cards — this is not a lifestyle app
- Multi-step wizard flows for simple actions — professionals want direct manipulation
- "Coming soon" placeholders or empty feature shells — either build it fully or don't show it
- Generic AI aesthetics (gradient blobs, emoji-heavy, corporate stock photos)
- Feature-gating that hides entire data categories from free users
- Decorative elements that don't convey information

## Feature Filter

Before building any feature, answer: **"Would an institutional-grade professional pay for this?"**

If the answer is no, the feature is not done. Revisit the design principles and the competitive landscape (`references/competitive-landscape.md`) to understand the bar.

## Institutional-Grade Checklist

Every feature must satisfy all 6 before shipping:
- [ ] Sub-second loads
- [ ] All states handled: loading, empty, error
- [ ] Every number traceable to source
- [ ] Works at 3am unattended
- [ ] Information density over whitespace
- [ ] No half-built sections
