---
name: security-posture
description: This skill should be used when the user asks to "add an API route", "handle user input", "write a webhook", "add authentication", "security review", "security audit", "is this secure", "validate input", "add rate limiting", "add CSRF", "RLS", "env vars", "email template", "stripe integration", "payment flow", "send email", or before any code that touches auth, user data, API boundaries, or external inputs . The unified security contract.
version: 0.1.0
---

# Security Posture

**TL;DR**: 16 security invariants. Every API route, user input handler, and data boundary must satisfy these.

## The 16 Invariants

### Server-Side Isolation
1. **`server-only` imports** — All sensitive modules (DB clients, API keys, scoring, pipeline) use `import "server-only"`. Client components never import server modules.
2. **Env validation** — All `process.env` access routed through `getServerEnv()` / `getPublicEnv()` from `src/lib/env.ts`. No direct `process.env` usage anywhere.
3. **Column-level RLS** — Row Level Security enabled on all tables. Policies grant minimum necessary access. Admin client (`createAdminClient()`) used for writes; cookie client for reads.

### Authentication & Authorization
4. **`verifyCronSecret()`** — Pipeline and cron routes verify `CRON_SECRET` header. Returns JSON error if missing/invalid.
5. **Middleware matcher** — Every route under `(dashboard)/` has a corresponding entry in `middleware.ts` config.matcher. Missing routes = silent auth bypass (sessions not refreshed → RLS sees `anon` role).
6. **Stripe webhook verification** — `constructEventWithSecret()` verifies signature + checks replay window. Webhook secret in `STRIPE_WEBHOOK_SECRET` env var.

### Input Validation
7. **Zod validation** — All user input validated with Zod schemas before processing. Trust nothing from the client.
8. **CSRF tokens** — State-changing POST routes verify CSRF token. Prevents cross-site request forgery.
9. **Rate limiting** — Public endpoints use rate limiter. Note: in-memory limiter resets on cold starts (see `references/known-limitations.md`).

### Output Safety
10. **`escapeHtml()`** — All user-provided strings in email templates escaped via shared `escapeHtml()` from `src/lib/email.ts`. Prevents XSS in weekly digest, alert emails, welcome emails.
11. **JSON error responses** — API routes wrap all throwable code in try/catch returning JSON. Unhandled throws produce HTML 500 → client `res.json()` fails. Every route has a single outer try/catch.
12. **No secret logging** — Never log API keys, tokens, user emails, Stripe customer IDs, or webhook payloads. Use structured logger with sanitized context.

### Data Safety
13. **No SQL injection** — Parameterized queries only via Supabase client. Never construct raw SQL strings from user input.
14. **Env three-way sync** — New env vars must be added to: `src/lib/env.ts` (validation) + Vercel dashboard + GitHub Secrets (for Actions). All three must stay in sync.
15. **Optional env documentation** — Env vars that are optional (e.g., feature-flagged sources) documented with `@optional` comments in `env.ts`.

### Supply Chain
16. **Dependency auditing** — `npm audit --audit-level=high` runs in CI and Husky pre-commit hook. Block on high/critical vulnerabilities. Stripe API version pinned. npm overrides for unpatched transitive CVEs.

## When Adding an API Route

Verify all of:
- Route is in try/catch returning JSON errors
- Auth check (getUser or verifyCronSecret)
- Input validated with Zod
- CSRF token on POST routes
- Rate limiting on public endpoints
- If under `(dashboard)/`, middleware matcher updated
- No secrets logged
- Env vars in env.ts + Vercel + GitHub Secrets

## When Handling User Input

Verify all of:
- Zod schema validates shape and bounds
- String inputs escaped before email/HTML rendering
- No raw user strings in SQL or PostgREST filters
- Error messages don't leak internal state

## When Writing a Webhook Endpoint

Verify all of:
- Signature verified via `constructEventWithSecret()` — never trust unverified payloads
- Replay window checked (webhook_events table stores event IDs, reject duplicates)
- Idempotency key on any state-changing operations triggered by the webhook
- Event type handled with switch/case, not open-ended if/else
- Log event type + event ID only — never log the full payload (contains PII and payment details)
- Return 200 quickly — offload long processing to avoid webhook timeout retries
- Rate limiting on webhook endpoint — prevent abuse from spoofed requests
- Webhook secret stored in env var, validated via `getServerEnv()`

## When Sending Email

Verify all of:
- All user-provided strings passed through `escapeHtml()` from `src/lib/email.ts`
- Template variables (name, ticker, summary) are ALL escaped before interpolation
- Digest body items are intentional HTML from callers — these are NOT escaped in the template
- Test with XSS payloads in user-controlled fields: `<script>alert(1)</script>` in name, ticker
- Rate limit email sends — no duplicate alerts within cooldown period
- No double-escaping (escape once at template boundary, not at both caller and template)
- Subject line length capped and sanitized — no user-controlled strings in subject without escaping and truncation

## Implementation File Quick Reference

| File | Guards | Check When |
|------|--------|------------|
| `src/lib/env.ts` | Env var validation (getServerEnv/getPublicEnv) | Adding env vars |
| `src/middleware.ts` | Session refresh, route matching | Adding dashboard routes |
| `src/lib/verify-cron.ts` | CRON_SECRET header check | Adding cron/pipeline routes |
| `src/lib/stripe/server.ts` | Stripe client, apiVersion pin | Stripe integration changes |
| `src/lib/email.ts` | escapeHtml, email templates | Email template changes |

See `references/security-audit-history.md` for the security audit history template.
See `references/known-limitations.md` for the known limitations template.

---
## See Also
- [database-query-safety](../database-query-safety/SKILL.md) — RLS policies and query patterns overlap: both enforce data access boundaries [related]
- [deploy-readiness](../deploy-readiness/SKILL.md) — Security invariants must be verified before production deploy [enforcement]
