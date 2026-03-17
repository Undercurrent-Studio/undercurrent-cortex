# Known Security Limitations — Template

Document accepted risks and their mitigation status. Review quarterly or when relevant infrastructure changes.

## Active Limitations

### In-Memory Rate Limiter
- **Risk**: Rate limiter state lives in serverless function memory. Each cold start resets all counters. A determined attacker can bypass by waiting for cold starts or hitting different instances.
- **Mitigation**: Acceptable for current scale. Rate limiting still prevents casual abuse and accidental loops.
- **Fix path**: Redis-based rate limiter (requires external Redis service like Upstash or similar).

### No MFA/TOTP
- **Risk**: Account takeover via compromised password. No second factor available.
- **Mitigation**: Auth provider handles password hashing, email verification, and session management. OAuth providers add implicit 2FA for users who have it enabled.
- **Fix path**: Optional TOTP for paid users. Low urgency if no payment methods stored on-site.

### Eager Environment Validation
- **Risk**: Centralized env validation checks ALL server env vars even if a route only needs one. A missing non-critical API key crashes unrelated routes.
- **Mitigation**: All env vars must be set on every deployment. Fail-fast is intentional (security hardening) but requires discipline.
- **Fix path**: Per-route validation of only needed vars (reduces blast radius).

## Resolved (Previously Active)

| Limitation | Resolution | When |
|-----------|------------|------|
| Dev bypass in cron auth | Removed entirely | Security audit |
| Missing middleware routes | All protected routes covered | Security audit |
| Direct `process.env` usage | Centralized via env validation module | Security audit |
| Unescaped user strings in emails | `escapeHtml()` applied | Security audit |
| Webhook replay attacks | Replay window check added | Security audit |
| SDK version unpinned | Pinned to specific version | Security audit |
