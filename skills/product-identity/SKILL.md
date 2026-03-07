---
name: product-identity
description: This skill should be used when the user asks to "design a feature", "build a new component", "plan a page", "add functionality", "what tier should this be", "free or pro", "should we gate this", "spec out a feature", "what's the quality bar", "pricing decision", "upgrade flow", "paywall", or before any product decision in the Undercurrent project. Encodes the product mission, quality bar, and design principles that every feature must satisfy.
version: 0.1.0
---

# Product Identity

**TL;DR**: Undercurrent is an institutional-grade stock research platform. Every feature must pass the professional analyst test.

## Mission

Stock research data aggregation platform that surfaces hidden and correlated signals from 18+ free public data sources. Data-forward UX: all raw data visible free, Pro unlocks depth. Not a data viewer — a research TOOL for maximum depth and signal discovery.

**Target user**: Professional analysts, portfolio managers, and serious retail investors who want Bloomberg-grade data density without the Bloomberg price tag.

## Design Principles

1. **Performance** — Sub-second loads, efficient queries, lazy loading. Data feels instant.
2. **Data Integrity** — Every number accurate and traceable. Pipeline failures never corrupt data.
3. **UX Density** — Information density over whitespace. Scannable tables, sparklines, tooltips.
4. **Reliability** — Works at 3am unattended. Circuit breakers, error boundaries, atomic ops.
5. **Feature Completeness** — No half-built features. Loading, empty, error, and edge case states.
6. **Polish** — Consistent spacing, alignment, color. Transitions where they add clarity.

Full definitions in CLAUDE.md § Product Vision & Standards.

## Free vs Pro Philosophy

Raw data is free — gating is on **depth**, not on **access**:
- Free users see the same data types as Pro — just fewer stocks, shorter history, fewer watchlist slots
- Pro unlocks depth: full universe, full history, unlimited watchlist, advanced features
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
- Sub-second loads
- All states handled: loading, empty, error
- Every number traceable to source
- Works at 3am unattended
- Information density over whitespace
- No half-built sections
