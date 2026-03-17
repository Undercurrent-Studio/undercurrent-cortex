keywords: deploy,vercel,go live,push to prod,production,ship it
# Deploy Readiness Context

**Untracked files**: Run `git status` before push. Untracked files imported by committed code cause "Module not found" on Vercel (files exist locally but not in git). Verify with `git ls-files <path>`.

**Environment variables**: If your project uses eager env validation (validating ALL server env vars on every route), ensure all are set in Vercel dashboard. Common categories: DATABASE_URL, DATABASE_ANON_KEY, DATABASE_SERVICE_ROLE_KEY, PAYMENT_SECRET_KEY, PAYMENT_WEBHOOK_SECRET, AI_API_KEY, CRON_SECRET, NEXT_PUBLIC_APP_URL, NEXT_PUBLIC_DATABASE_URL, NEXT_PUBLIC_DATABASE_ANON_KEY.

**Service worker cache**: If your project uses a service worker, bump the cache version name on deploys. Activate handler auto-deletes old caches.

**Pre-deploy checklist**: lint clean, tsc clean, full test suite passes, documentation updated if architectural files changed, conventional commit message.
