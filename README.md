# Undercurrent Plugin

A Claude Code plugin that provides a compounding intelligence system for the [Undercurrent](https://undercurrent.finance) stock research platform. It injects domain knowledge, enforces quality gates, and tracks session health across conversations.

## What It Does

- **14 skills** inject domain-specific knowledge when relevant topics are detected (scoring, migrations, security, pipeline, etc.)
- **12 hooks** across 7 lifecycle events enforce quality gates, track state, and inject context automatically
- **1 agent** (conversation-analyzer) detects recurring mistake patterns and proposes prevention
- **6 context files** inject domain-specific gotchas when keywords are detected in user prompts
- **2 slash commands** (`/analyze-session`, `/session-end`) trigger workflows on demand

## Requirements

- **Claude Code** (CLI or VS Code extension)
- **Git Bash** — all hook scripts require `bash`. On Windows, hooks invoke `"C:/Program Files/Git/bin/bash.exe"` explicitly.
- **Working directory**: The hooks are project-aware — they check if the current directory is the Undercurrent repo before firing.

## Installation

The plugin is installed via Claude Code's plugin system. It lives in three synced locations:

| Location | Purpose |
|----------|---------|
| `Code Projects/undercurrent-plugin/` | **Source of truth** — edit here |
| `~/.claude/plugins/cache/.../undercurrent/` | **Runtime cache** — hooks.json references scripts here |
| `~/.claude/skills/` | **Skill discovery** — Claude Code auto-discovers skills here |

### Initial Setup

1. Clone this repo to `C:/Users/<you>/Desktop/Code Projects/undercurrent-plugin/`
2. Run the sync script:
   ```bash
   cd undercurrent-plugin
   bash scripts/sync-plugin.sh
   ```
3. Restart Claude Code to pick up hooks and skills

### After Making Changes

Always edit files in the source directory, then sync:

```bash
bash scripts/sync-plugin.sh
```

The sync script:
- Copies hooks, skills, commands, agents, and context to the plugin cache
- Copies skills to `~/.claude/skills/` for auto-discovery
- Copies to `undercurrent-v1/.claude-plugin/` as a project mirror
- Verifies hook registration count, no nested directories, and no stale settings.json hooks

**You must restart Claude Code after syncing** for hook changes to take effect. Skill content changes are picked up without restart.

## Directory Structure

```
undercurrent-plugin/
  .claude-plugin/
    plugin.json              # Plugin manifest (name, version, description)
  hooks/
    hooks.json               # All 12 hook registrations
    session-start            # SessionStart command hook (existing)
    scripts/
      post-edit-dispatch.sh  # PostToolUse (Write|Edit) — tracks files, nudges commits
      post-bash-dispatch.sh  # PostToolUse (Bash) — tracks tool count, test gate
      migration-linter.sh    # PreToolUse (Write|Edit) — blocks now() in WHERE
      plan-file-guard.sh     # PreToolUse (Write) — protects plan files from overwrite
      context-flow.sh        # UserPromptSubmit — injects domain context by keyword
      stop-gate.sh           # Stop — enforces uncommitted/docs/test/carry-over gates
      pre-compact.sh         # PreCompact — preserves carry-over before compaction
      session-end-dispatch.sh# SessionEnd — writes health metrics to log
      lib/
        escape-json.sh       # JSON string escaping utility
        json-extract.sh      # Lightweight JSON field extraction (no jq dependency)
        state-io.sh          # INI-style state file read/write operations
  skills/                    # 14 skill directories (each has SKILL.md + optional references/)
  commands/
    session-end.md           # /session-end slash command
    analyze-session.md       # /analyze-session slash command
  agents/
    conversation-analyzer.md # Adaptive immunity agent (pattern detection + proposals)
  context/                   # 6 domain context files (~150 words each)
  scripts/
    sync-plugin.sh           # Deployment script (source -> cache + skills + mirror)
```

## Hook Architecture

### Lifecycle Flow

```
SessionStart ──> UserPromptSubmit ──> PreToolUse ──> [tool runs] ──> PostToolUse
                                                                          |
                                                                    PreCompact (if needed)
                                                                          |
                                                                        Stop
                                                                          |
                                                                      SessionEnd
```

### Hook Inventory

| Event | Matcher | Type | Script | What It Does |
|-------|---------|------|--------|-------------|
| SessionStart | * | command | session-start | Initializes state, loads health trends |
| PostToolUse | Bash | command (sync) | post-bash-dispatch.sh | Tracks tool count, detects test runs, logs commits |
| PostToolUse | Write\|Edit | command (sync) | post-edit-dispatch.sh | Tracks edited files, nudges commits, detects doc drift |
| PreToolUse | Write\|Edit | command | migration-linter.sh | **DENY** `now()`/`CURRENT_DATE` in migration WHERE clauses |
| PreToolUse | Write\|Edit | command | plan-file-guard.sh | **DENY** overwriting plan files >50 lines |
| PreToolUse | Write\|Edit | prompt | (inline) | Reminds about dashboard route auth checks |
| PreToolUse | Write\|Edit | prompt | (inline) | Checks for 8 PostgREST gotchas in Supabase queries |
| PreToolUse | Write | command | plan-file-guard.sh | Protects existing plan files from overwrite |
| PreToolUse | Bash | prompt | (inline) | Pre-push checks (untracked files, tests, docs, force-push) |
| UserPromptSubmit | * | command (sync) | context-flow.sh | Keyword-based domain context injection |
| Stop | * | command (sync) | stop-gate.sh | 4 gates: uncommitted edits, doc sync, tests, carry-over |
| PreCompact | * | command (sync) | pre-compact.sh | Preserves carry-over tags before context compaction |
| SessionEnd | * | command | session-end-dispatch.sh | Writes 9 session metrics to health log |

**Command hooks** run bash scripts and can read/write files. **Prompt hooks** inject natural language reminders into the conversation.

### Barrier Hooks (PreToolUse)

These can **block** operations:
- `migration-linter.sh` — DENYs migrations with `now()`, `CURRENT_DATE`, or `clock_timestamp()` in WHERE clauses (PostgreSQL partial indexes require IMMUTABLE functions)
- `plan-file-guard.sh` — DENYs overwriting plan files with >50 lines (prevents accidental plan destruction)

### Gate Hooks (Stop)

`stop-gate.sh` checks 4 conditions before allowing session end:
1. No uncommitted file edits
2. Documentation in sync (if architectural files changed)
3. Tests pass (if test files were modified)
4. No unresolved carry-over items

After 3 consecutive blocks, a force-approve escape hatch activates.

## Skills

14 skills across 4 layers:

| Layer | Skill | Triggers On |
|-------|-------|-------------|
| **Mission** | product-identity | "design a feature", "what tier", "free or pro", "quality bar" |
| **Mission** | security-posture | "add API route", "webhook", "is this secure", "RLS", "env vars" |
| **Mission** | data-integrity | "display data", "fix wrong data", "debug null values", "stale cache" |
| **Domain** | database-query-safety | Any Supabase/PostgREST query writing |
| **Domain** | pipeline-change-checklist | Modifying pipeline, sync-tickers, sentiment worker |
| **Domain** | migration-safety | Writing/reviewing Supabase migrations |
| **Domain** | scoring-change-checklist | Modifying scoring sub-factors, weights, transfer functions |
| **Domain** | github-actions-safety | Creating/modifying GitHub Actions workflows |
| **Workflow** | feature-design-flow | Starting any feature or architectural decision |
| **Workflow** | pre-commit-checklist | Before any git commit or PR |
| **Workflow** | deploy-readiness | Before deploying to production |
| **Learning** | session-start | Starting or resuming a session |
| **Learning** | session-end | Wrapping up a working session |
| **Learning** | pattern-escalation | When a problem class appears 2+ times |

Skills are markdown files with YAML frontmatter. Claude Code loads them based on the `description` field's trigger phrases.

## Context Files

Injected automatically by `context-flow.sh` when user prompts match keywords:

| File | Keywords |
|------|----------|
| scoring-architecture.md | score, scoring, pillar, weight, percentile |
| migration-lessons.md | migration, migrate, alter, schema, column |
| pipeline-constraints.md | pipeline, cron, batch, ticker, circuit |
| deploy-readiness.md | deploy, production, ship, release, vercel |
| testing-conventions.md | test, vitest, coverage, mock, assertion |
| payment-integration.md | stripe, payment, subscription, checkout, webhook, billing |

## State Files

The plugin maintains state across sessions via files in the project's `.claude/` directory (gitignored):

| File | Purpose |
|------|---------|
| `.claude/undercurrent-state.local.md` | Current session state (files edited, commits, tool count) |
| `.claude/undercurrent-health.local.md` | Rolling session health metrics (pipe-delimited log) |
| `.claude/undercurrent-proposals.local.md` | Pending improvement proposals from conversation-analyzer |

## Troubleshooting

### Hooks not firing
- Restart Claude Code after syncing
- Verify hooks.json exists in cache: `cat ~/.claude/plugins/cache/.../hooks/hooks.json`
- Check that Git Bash is at `C:/Program Files/Git/bin/bash.exe`

### Skills not appearing
- Run `sync-plugin.sh` and check "Synced: 14 skills" output
- Verify skill directories exist in `~/.claude/skills/`
- Each skill directory must contain a `SKILL.md` with valid YAML frontmatter

### Hook errors
- All command hooks use `set -euo pipefail` and exit 0 on errors (never block operations on script failure)
- Check the script directly: `bash hooks/scripts/<script>.sh` with test input
- PreToolUse command hooks that DENY must output JSON: `{"hookEventName":"PreToolUse","decision":"DENY","reason":"..."}`

### Sync issues
- Always edit in `undercurrent-plugin/` (source), never in cache or skills directories
- `cp -r dir/` on Git Bash doesn't overwrite existing files — sync script handles this explicitly
- If cache path changes, update paths in `scripts/sync-plugin.sh`

## Development

### Adding a new skill
1. Create `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `version`)
2. Add reference files in `skills/<name>/references/` if needed
3. Run `sync-plugin.sh`
4. Test: type a trigger phrase and verify the skill appears in Claude Code's skill list

### Adding a new hook
1. Create script in `hooks/scripts/`
2. Add registration to `hooks/hooks.json`
3. Run `sync-plugin.sh` and restart Claude Code
4. Smoke test the trigger condition

### Modifying context files
1. Edit in `context/`
2. Update keyword matching in `hooks/scripts/context-flow.sh` if adding new files
3. Run `sync-plugin.sh`

## Version History

- **2.0.0** — Full plugin (Parts A-J): 14 skills, 12 hooks, 1 agent, 6 context files, 2 commands
- **1.0.0** — Initial scaffold (session-start hook only)
