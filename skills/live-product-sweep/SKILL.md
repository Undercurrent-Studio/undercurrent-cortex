---
name: live-product-sweep
description: Run an exhaustive element-level sweep of the live Undercurrent app — inventories every component, data point, and interaction on every page, cross-references displayed values against Supabase, and outputs a structured JSON regression baseline with provable coverage metrics. Trigger when the user says "sweep the live site", "run a product sweep", "check every page", "full site check", "sweep undercurrent", or "live-product-sweep". Do NOT trigger on generic "audit" requests.
version: 1.0.0
---

# Live Product Sweep

Launch the `live-product-sweep` agent to perform a full product sweep of the live site at undercurrent.finance.

Pass the user's arguments (if any) directly to the agent:
- Tickers to test (default: AAPL, TSLA, NVDA): `/live-product-sweep AAPL MSFT`
- Single page: `/live-product-sweep --page /dashboard`
- Resume incomplete sweep: `/live-product-sweep --resume`
