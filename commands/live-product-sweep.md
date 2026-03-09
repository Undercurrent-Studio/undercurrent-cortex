---
name: live-product-sweep
description: Run an exhaustive element-level sweep of the live Undercurrent app — inventories every component, data point, and interaction, cross-references against Supabase, outputs JSON regression baseline
---

Launch the `live-product-sweep` agent to perform a full product sweep of the live site.

The agent will:
1. Discover all routes from `src/app/` + hardcoded configs for complex pages
2. Authenticate with test credentials
3. Sweep every page: DOM census, full-scroll element inventory, interaction testing, console checks
4. Cross-reference displayed values against Supabase
5. Output structured JSON to `sweeps/YYYY-MM-DD-HHMMSS.json` with coverage metrics

Pass optional arguments to customize:
- Tickers to test (default: AAPL, TSLA, NVDA): `/live-product-sweep AAPL MSFT`
- Single page: `/live-product-sweep --page /dashboard`
- Resume incomplete sweep: `/live-product-sweep --resume`

ARGUMENTS: optional ticker list, --page flag, or --resume
