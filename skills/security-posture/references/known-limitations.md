# Known Security Limitations

Accepted risks and their mitigation status. Review quarterly or when relevant infrastructure changes. Next scheduled review: 2026-06-01.

## Active Limitations

### In-Memory Rate Limiter (P2 Backlog)
- **Risk**: Rate limiter state lives in serverless function memory. Each cold start resets all counters. A determined attacker can bypass by waiting for cold starts or hitting different instances.
- **Mitigation**: Acceptable for current scale. Rate limiting still prevents casual abuse and accidental loops.
- **Fix path**: Redis-based rate limiter (P2 backlog item). Requires external Redis service (Upstash or similar).

### No MFA/TOTP (P3 Backlog)
- **Risk**: Account takeover via compromised password. No second factor available.
- **Mitigation**: Supabase Auth handles password hashing (bcrypt), email verification, and session management. OAuth (GitHub) adds implicit 2FA for users who have it enabled on their GitHub account.
- **Fix path**: Optional TOTP for Pro users (P3 backlog). Low urgency — no payment method stored on-site (Stripe handles billing).

### Eager Env Validation
- **Risk**: `getServerEnv()` validates ALL 10+ server env vars even if a route only needs 1. A missing `EIA_API_KEY` crashes the checkout route.
- **Mitigation**: All env vars must be set on every deployment (Vercel + GitHub Secrets). Fail-fast is intentional — prevents partial deployments.
- **Impact**: If a new env var is added but not deployed, ALL server routes fail. This is by design (security hardening) but requires discipline.

### Stripe `past_due` Grace Period
- **Risk**: Users with failed payments retain Pro access during Stripe's retry period (up to ~2 weeks).
- **Mitigation**: Intentional business decision. Stripe retries payment automatically. If all retries fail, subscription transitions to `canceled` and access is revoked. Grace period prevents churn from temporary card issues.

### PostHog Transitive Vulnerability
- **Risk**: `dompurify` moderate severity vulnerability in PostHog's transitive dependency chain.
- **Mitigation**: No upstream fix available. PostHog runs client-side only (analytics). The vulnerability is in HTML sanitization — PostHog doesn't process user HTML. Risk is theoretical.
- **Fix path**: Waiting for upstream package update. `npm audit --audit-level=high` CI gate skips moderate-level issues.

## Resolved (Previously Active)

| Limitation | Resolution | When |
|-----------|------------|------|
| Dev bypass in `verifyCronSecret()` | Removed entirely | Opus Audit Session 1 |
| Missing middleware routes | All `(dashboard)/` routes covered | Opus Audit Session 1 |
| Direct `process.env` usage | Centralized via `env.ts` | Opus Audit Session 7 |
| Unescaped user strings in emails | `escapeHtml()` applied | Opus Audit Session 6 |
| Webhook replay attacks | Replay window check added | Opus Audit Session 1 |
| Stripe version unpinned | Pinned to `2026-02-25.clover` | Opus Audit Session 1 |
