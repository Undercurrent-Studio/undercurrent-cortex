---
name: pre-commit-checklist
description: This skill should be used before any git commit or PR — runs automated checks and institutional quality gates.
version: 0.1.0
---

# Pre-Commit Checklist

**TL;DR**: Untracked files → lint → tsc → tests if pipeline/DB touched → institutional bar.

## Automated gates (all must pass)
1. `git ls-files --others --exclude-standard` — any untracked file imported by committed code? Stage it first. (Untracked files = Vercel "Module not found".)
2. `npm run lint` — must pass. No `--max-warnings` flag (matches CI).
3. `npx tsc --noEmit` — zero type errors.
4. If `src/lib/pipeline/`, `src/lib/scoring/`, or DB code touched → `npm test -- --run`.
5. If migration files staged: check for `now()` in WHERE (IMMUTABLE violation, 3x repeat offender), verify constraint names match production schema, use IF NOT EXISTS patterns.
6. For every new import path in staged files, verify the target file is tracked: `git ls-files <path>`. Untracked imports = Vercel build failure.

See `scripts/pre-commit-gates.sh` for an automated runner covering gates 1-6.

## Manual review gates (answer before committing)
- Does this diff touch only files within scope of the task? (scope creep check)
- If new page route under `(dashboard)/`, is middleware matcher updated?
- If new env var, is it in env.ts + Vercel + GitHub Secrets + workflow YAML?
- If new utility in `src/lib/`, does it have tests?
- Are all untracked files imported by committed code staged?

## Institutional-grade gate (all must be yes before committing)
- Sub-second loads / no perceptible lag
- All states handled: loading, empty, error
- Every number traceable to its source
- Works at 3am unattended
- Information density over whitespace
- No half-built sections

## Reference file staleness check (warning, not block)
If commits touch domain code, check if the corresponding reference file needs updating:
- `src/lib/scoring/` → `references/scoring.md`
- `src/lib/pipeline/` → `references/pipeline.md`
- `src/lib/signals/` → `references/signals.md`
- `src/app/api/` → `references/api-routes.md`
- `.github/workflows/` → `references/github-actions.md`
- `supabase/migrations/` → `references/database.md`
- `src/app/`, `src/components/` → `references/frontend.md`
- `src/lib/data-sources/` → `references/data-sources.md`
- `src/middleware.ts`, `src/lib/supabase/` → `references/auth.md`

This is a warning — don't block the commit, but flag if a reference file may be stale after this change.

All checks are gates, not warnings — except the reference staleness check above. Fix gates before committing.

---
## See Also
- [deploy-readiness](../deploy-readiness/SKILL.md) — Per-commit gates feed into per-deploy verification in the release pipeline [workflow]
- [plan-audit](../plan-audit/SKILL.md) — Plan audit validates design; pre-commit checklist validates each commit [workflow]
- [tdd-enforcement](../tdd-enforcement/SKILL.md) — TDD ensures tests exist; pre-commit gates ensure they pass [enforcement]
