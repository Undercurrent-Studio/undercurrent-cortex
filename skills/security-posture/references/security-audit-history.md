# Security Audit History

## Opus Audit Sessions 1-9 (2026-03-03/04)

38 pre-identified findings + ~80 session-discovered findings across 9 sessions. 27 fixed, 6 verified OK, 3 deferred, 2 documented risks. 30 commits. Full accounting in `.claude/plans/curried-chasing-lake.md`.

### Session 1: P0 Security + Quick Wins (11 findings)
- Stripe `past_due` grace period (maps to "pro", not "canceled")
- Migration dedup safety
- Weekly digest tier gate
- Stripe API version pinned (`2026-02-25.clover`)
- Dev bypass removed from `verifyCronSecret()`
- Middleware gaps patched
- Env validation routing
- Webhook replay window enforcement
- SW cache versioning (date-based `CACHE_NAME`)
- Dynamic OG images (opengraph-image.tsx convention)
- Alerts skeleton loading state

### Session 2: Security & Auth (9 findings)
- `webhook_events` table RLS policies
- Portfolio CSRF + rate-limit enforcement
- Notification ID validation (UUID format)
- Alert `scope_value` validation + UUID format check
- CSP documentation
- `process.env` routing documentation

### Session 3: Database Schema & Query Integrity (19 findings)
- `webhook_events` RLS policy hardening
- Portfolio CSRF token + rate-limit enforcement on mutations
- Notification ID validation (UUID format check)
- Alert `scope_value` validation + UUID format enforcement
- Schema constraint naming audit (auto-generated vs explicit)
- Query return type verification (PostgREST silent null on bad columns)
- Index optimization for frequently filtered columns
- Foreign key integrity checks across signal tables

### Session 4: Pipeline Reliability & Data Sources (10 findings)
- EIA/TSA error handling hardened
- Cache invalidation tags rotated
- EDGAR multi-filer dedup + gift transaction filter
- StockTwits minimum sample threshold
- Google Trends short ticker skip
- Convergence atomic upsert (migration 052)
- `sync-tickers` re-list mechanism for false delistings

### Session 5: Scoring Engine Validation (6 findings)
- `interestCoverage` debt-free fix (999 sentinel value)
- `surpriseMagnitude` recency weighting wired up
- Convergence direction null=0 alignment

### Session 6: Frontend Architecture & UX (9 findings)
- Email XSS hardening (`escapeHtml` in 3 email templates)
- Server-side locale fixes (explicit `"en-US"`)
- Stock tabs ARIA + keyboard navigation
- Data table `aria-sort` attributes

### Session 7: Dependencies, TypeScript, Testing (mixed)
- Convergence engine tests (29 new)
- Middleware tests (20 new)
- Centralized `process.env` via `env.ts`
- Removed dead `serverExternalPackages`
- Updated stripe/yahoo-finance2/sentry packages

### Session 8: Operations, SEO, PWA, Cost (mixed)
- Pipeline Sentry error capture
- Stale `robots.txt` deleted
- SW cache bump
- CI `npm audit --audit-level=high`
- Sitemap 500 to 10K entries + 24h cache
- Weekly digest `maxDuration: 300s` + time-budget guard

### Session 9: Synthesis & Prioritization
- Final accounting of all findings
- Backlog triaged into P0-P3 launch readiness tiers
- 43 items categorized

## Key Security Patterns Established

| Pattern | Where | Why |
|---------|-------|-----|
| `escapeHtml()` | `src/lib/email.ts` | Prevent XSS in all email templates |
| `verifyCronSecret()` | Pipeline routes | Prevent unauthorized cron execution |
| JSON error wrapping | All API routes | Prevent HTML 500 → client parse failure |
| Stripe version pinning | `src/lib/stripe/server.ts` | Prevent breaking changes from auto-upgrades |
| `getServerEnv()` | All server modules | Centralized validation, fail-fast on missing vars |
| Middleware matcher | `middleware.ts` | Ensure session refresh on all protected routes |
| CSRF tokens | POST routes | Prevent cross-site state changes |
| Rate limiting | Public endpoints | Prevent abuse (note: in-memory, resets on cold start) |
