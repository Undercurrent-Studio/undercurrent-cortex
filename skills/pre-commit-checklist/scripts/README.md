# Pre-Commit Gates Script

Automated gate runner for the Undercurrent pre-commit checklist.

## Usage

```bash
bash skills/pre-commit-checklist/scripts/pre-commit-gates.sh
```

## What It Checks

| Gate | What | Blocks on |
|------|------|-----------|
| 1 | Untracked TypeScript files | Warning only (manual check) |
| 2 | `npm run lint` | Lint errors |
| 3 | `npx tsc --noEmit` | Type errors |
| 4 | `npm test -- --run` | Test failures (only if pipeline/DB/scoring touched) |
| 5 | Migration safety | `now()` in WHERE (hard block), missing RLS/IF EXISTS (warning) |

## Note

This is a **reference script**, not a git hook. The project's Husky pre-commit hook (`.husky/pre-commit`) runs `npm audit --audit-level=high`. This script covers the broader pre-commit checklist items that require manual or context-aware evaluation.

Run this script before committing when you want the full automated gate check. The institutional-grade gate (6 items) is assessed manually per the skill.
