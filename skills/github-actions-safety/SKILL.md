---
name: github-actions-safety
description: This skill should be used before creating or modifying GitHub Actions workflows in the Undercurrent project — permissions, timeouts, cron expressions, artifact handling, secret management, and schedule conflict avoidance.
version: 0.1.0
---

# GitHub Actions Safety

**TL;DR**: 8 rules for safe workflow authoring. Undercurrent has 11 workflows — new ones must not conflict.

## The 8 Rules

### 1. Permissions — Principle of Least Privilege

Every workflow MUST have top-level permissions:
```yaml
permissions:
  contents: read
```
Never grant `write` unless the workflow actually pushes code (none currently do). This prevents accidental repository modification if a step is compromised.

### 2. Job Timeouts — Always Set

Every job MUST have `timeout-minutes`. Without it, a stuck job runs for 6 hours (GitHub default).

| Job Type | Timeout |
|----------|---------|
| CI (lint, test, build) | 15 min |
| Scraper (Playwright) | 30 min |
| Data jobs (fundamentals, EDGAR) | 20 min |
| Long-running (backfill) | 30 min |

Add step-level timeouts for individual long-running steps where appropriate.

### 3. Cron Expressions — Document and Verify

Document the schedule in a comment next to every cron expression:
```yaml
schedule:
  - cron: "30 8 * * *"  # Daily at 08:30 UTC — signal analysis
```

Before adding a new schedule:
1. Check `references/workflow-inventory.md` for existing schedules
2. Verify no overlap with Vercel pipeline (runs every 10 min)
3. Verify no overlap with sentiment worker (03:00/15:00 UTC)
4. Use https://crontab.guru to validate the expression

### 4. Secret Management

Use `${{ secrets.NAME }}` for all sensitive values. Never hardcode API keys or tokens.

New secrets must be added to all 3 locations:
1. `src/lib/env.ts` — validation
2. Vercel dashboard — production runtime
3. GitHub Secrets — Actions runtime

Document which secrets each workflow uses in the workflow's env block.

### 5. Node Version — Pin via .nvmrc

Use `actions/setup-node@v4` with the project's `.nvmrc` file:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version-file: ".nvmrc"
    cache: npm
```

The project requires Node 22 (`engines: { node: ">=22" }` in package.json). Never hardcode a Node version in workflows — always reference `.nvmrc`.

### 6. Dependency Caching

Always include `cache: npm` in the `setup-node` step. Saves ~30s per run by caching `node_modules`.

### 7. Error Handling in Scripts

`tsx` scripts run by workflows should exit with non-zero on fatal errors:
```ts
process.exit(1); // on fatal error
```

GitHub Actions treats non-zero exit as step failure. Without explicit `process.exit(1)`, a script that logs an error but doesn't throw will appear as a successful step.

### 8. Workflow Dispatch

Include `workflow_dispatch` for manual triggering during debugging:
```yaml
on:
  schedule:
    - cron: "30 8 * * *"
  workflow_dispatch:
    inputs:
      subcommand:
        description: "Subcommand to run"
        required: false
        default: "all"
```

The `signal-analysis.yml` pattern (subcommand input with default "all") is the reference for workflows with multiple modes.

See `references/workflow-inventory.md` for the complete inventory of all 11 workflows.
