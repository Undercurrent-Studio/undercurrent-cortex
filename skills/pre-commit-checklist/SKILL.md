---
name: pre-commit-checklist
description: This skill should be used before any git commit or PR in the Undercurrent project — runs automated checks and institutional quality gates.
version: 0.1.0
---

# Pre-Commit Checklist

**TL;DR**: Untracked files → lint → tsc → tests if pipeline/DB touched → institutional bar.

## Automated gates (all must pass)
1. `git ls-files --others --exclude-standard` — any untracked file imported by committed code? Stage it first. (Untracked files = Vercel "Module not found".)
2. `npm run lint` — must pass. No `--max-warnings` flag (matches CI).
3. `npx tsc --noEmit` — zero type errors.
4. If `src/lib/pipeline/`, `src/lib/scoring/`, or DB code touched → `npm test -- --run`.

## Institutional-grade gate (all must be yes before committing)
- [ ] Sub-second loads / no perceptible lag
- [ ] All states handled: loading, empty, error
- [ ] Every number traceable to its source
- [ ] Works at 3am unattended
- [ ] Information density over whitespace
- [ ] No half-built sections

All checks are gates, not warnings. Fix before committing.
