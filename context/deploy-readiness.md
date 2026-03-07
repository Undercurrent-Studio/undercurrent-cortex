# Deploy Readiness Context

**Untracked files**: Run `git status` before push. Untracked files imported by committed code cause "Module not found" on Vercel (files exist locally but not in git). Verify with `git ls-files <path>`.

**Environment variables**: `getServerEnv()` validates ALL 10 server env vars eagerly. Missing any one crashes the route. Ensure all are set in Vercel dashboard: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, ANTHROPIC_API_KEY, CRON_SECRET, NEXT_PUBLIC_APP_URL, NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY.

**Service worker cache**: Bump `CACHE_NAME = "undercurrent-YYYYMMDD"` in `public/sw.js` on deploys. Activate handler auto-deletes old caches.

**Stripe version**: apiVersion pinned `"2026-02-25.clover"` in `src/lib/stripe/server.ts`. Never leave unpinned. Matches SDK v20.4.0.

**Pre-deploy checklist**: lint clean, tsc clean, full test suite passes (1460 tests across 90 files), `documentation.md` updated if architectural files changed, conventional commit message.
