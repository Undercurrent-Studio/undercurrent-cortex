keywords: stripe,checkout,subscription,payment,billing,webhook
# Payment Integration Context

**Stripe webhook**: Endpoint at `/api/webhooks/stripe`. 3 events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`. Signing secret in `STRIPE_WEBHOOK_SECRET` env var. API version `2026-02-25.clover` pinned in `src/lib/stripe/server.ts` (matches SDK v20.4.0).

**Subscription states**: `past_due` maps to `"pro"` tier (grace period while Stripe retries payments). `active` = pro. `canceled`/missing = free.

**API route safety**: ALL throwable code in payment routes MUST be inside try/catch returning JSON. Unhandled throws produce HTML 500 -> client `res.json()` fails -> generic error. Key file: `src/app/api/checkout/route.ts`.

**Tier limits**: Free: 3 watchlist, top 500 stocks, 7-day charts, cached AI briefs, composite sentiment only. Pro ($30/mo): unlimited watchlist, ~6K stocks, full history, per-source sentiment, CFTC, full database explorer, on-demand AI briefs.

**Testing**: Shared helpers in `src/__tests__/helpers/mock-stripe.ts` — Stripe instance factory + event factory. Payment tests cover signature verification, replay prevention, idempotency, CSRF, rate limiting, ownership verification.
