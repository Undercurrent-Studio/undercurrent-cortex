# Security Audit History — Template

Document your security audit sessions here. Each session should focus on a specific domain and list findings with their resolution status.

---

## Example: Session 1 — Authentication & Authorization
- Payment provider grace period handling (map statuses correctly)
- Middleware route coverage (all protected routes in matcher)
- Cron/pipeline route secret verification
- Env validation routing (centralized, fail-fast)
- Webhook replay window enforcement
- Dev bypasses removed from auth checks

## Example: Session 2 — Data Integrity & Query Safety
- Database RLS policies on all sensitive tables
- CSRF token enforcement on mutation endpoints
- Input validation (Zod schemas on all user-facing endpoints)
- Query return type verification (PostgREST silent null on bad columns)
- Index optimization for frequently filtered columns
- Foreign key integrity across related tables

## Example: Session 3 — Frontend & Supply Chain
- XSS prevention in email templates (`escapeHtml()` on all user strings)
- Server-side locale consistency (explicit locale for date formatting)
- Keyboard navigation and ARIA attributes on interactive components
- Dependency auditing (`npm audit --audit-level=high` in CI)
- API version pinning on payment/external SDKs

---

## Key Security Patterns Established

| Pattern | Where | Why |
|---------|-------|-----|
| `escapeHtml()` | Email templates | Prevent XSS in all rendered user strings |
| `verifyCronSecret()` | Pipeline/cron routes | Prevent unauthorized scheduled task execution |
| JSON error wrapping | All API routes | Prevent HTML 500 → client parse failure |
| SDK version pinning | Payment/external SDKs | Prevent breaking changes from auto-upgrades |
| Centralized env validation | Server modules | Fail-fast on missing variables |
| Middleware matcher | Auth framework | Ensure session refresh on all protected routes |
| CSRF tokens | POST/mutation routes | Prevent cross-site state changes |
| Rate limiting | Public endpoints | Prevent abuse (note limitations of in-memory limiters) |
