---
name: deploy-readiness
description: This skill should be used on-demand before deploying to production — 13-item pre-deploy verification checklist. Trigger when the user says "deploy", "push to production", "ship it", "go live", "deploy readiness check", "ready to deploy", "release to prod", or "merge to master".
version: 0.1.0
---

# Deploy Readiness

**TL;DR**: 13-item checklist before any production deploy. On-demand only — not auto-triggered on every commit.

## Pre-Deploy Checklist

All items must pass before deploying:

### Code Quality
1. `npm run lint` — passes with zero warnings
2. `npx tsc --noEmit` — zero type errors
3. `npm test -- --run` — all tests pass
4. `npm audit --audit-level=high` — no high/critical vulnerabilities
5. No `console.log` left in production code — use structured logger

### Build Verification
6. `npm run build` — succeeds locally (with placeholder env vars if needed)
7. `git status` — no untracked files that are imported by committed code

### Configuration
8. All new env vars added to: `src/lib/env.ts` + Vercel dashboard + GitHub Secrets
9. Middleware matcher covers all new protected routes under `(dashboard)/`
10. SW cache version bumped in `public/sw.js` (if applicable — update the `CACHE_NAME` constant)

### Data & Schema
11. Migrations tested with `supabase db reset` locally before applying to production via Supabase dashboard

### Documentation
12. `documentation.md` updated for any new features, routes, or schema changes
13. `package.json` version updated if the change is semver-meaningful

## When to Run

This checklist is for production deploys, not for every commit. Run it when:
- Pushing a feature branch to master for the first time
- Deploying after a significant batch of changes
- User explicitly says "deploy", "ship it", "go live"

For per-commit checks, use the `pre-commit-checklist` skill instead.
