# Undercurrent Plugin

A Claude Code plugin that works like a **living organism** — 8 biological systems that build intelligence across sessions for the [Undercurrent](https://undercurrent.finance) stock research platform.

It watches what you do, learns from mistakes, blocks dangerous operations, injects domain knowledge at the right moment, and tracks your work health over time.

---

## Quick Start

### Requirements

- **Claude Code** (CLI or VS Code extension)
- **Git Bash** on your PATH (Windows: comes with [Git for Windows](https://git-scm.com/))

### Setup

**1. Install the plugin** via Claude Code's plugin system.

**2. Add dispatcher hooks to `~/.claude/settings.json`**

Plugin `hooks.json` can't fire command hooks for PreToolUse/PostToolUse events. Register them globally:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [{
          "type": "command",
          "command": "bash C:/Users/<you>/.claude/plugins/cache/claude-plugins-official/undercurrent/<hash>/hooks/scripts/pre-dispatch.sh",
          "timeout": 10
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [{
          "type": "command",
          "command": "bash C:/Users/<you>/.claude/plugins/cache/claude-plugins-official/undercurrent/<hash>/hooks/scripts/post-dispatch.sh",
          "timeout": 10
        }]
      }
    ]
  }
}
```

> **Syntax rules:** Use plain `bash` (not the full exe path). Forward slashes. No quotes around script path. Matcher must be `".*"` (regex).

**3. Restart Claude Code.**

---

## The 8 Biological Systems

### 1. Nervous System — State Tracking
Every edit, commit, and tool call is tracked. The plugin always knows what happened this session.

### 2. Immune System — Pre-Tool Guards
Blocks dangerous operations before they execute:
- `now()` in a migration WHERE clause → **Blocked** (PostgreSQL requires IMMUTABLE)
- Overwriting a plan file without reading it → **Blocked**

### 3. Circulatory System — Context Flow
Mention "scoring", "pipeline", or "stripe" and the plugin injects relevant domain knowledge. Also detects decision language and prompts for metadata to build a decision journal.

### 4. Skeletal System — Session Lifecycle
Initializes state at start, runs async codebase spot-checks, writes 9 health metrics at end.

### 5. Digestive System — Pattern Templates
When you create a new file, the plugin injects an exemplar from the codebase as a convention reference.

### 6. Endocrine System — Commit Enforcement
Nudges after 15+ edits without a commit. Validates conventional commit format on `git commit`.

### 7. Memory System — Stop Gates
Checks 4 things before allowing session end: edits committed, docs updated, tests pass, carry-over resolved. Escape hatch after 2 consecutive blocks.

### 8. Reproductive System — Evolution
The `conversation-analyzer` agent detects recurring patterns and proposes new rules. The plugin evolves itself.

---

## Components

### 16 Skills (4 layers)

| Layer | Skills |
|-------|--------|
| **Mission** | product-identity, security-posture, data-integrity |
| **Domain** | database-query-safety, pipeline-change-checklist, migration-safety, scoring-change-checklist, github-actions-safety |
| **Workflow** | feature-design-flow, pre-commit-checklist, deploy-readiness, plan-audit, plan-estimation |
| **Learning** | session-start, session-end, pattern-escalation |

### 14 Hooks

| Event | Script | Where | What |
|-------|--------|-------|------|
| SessionStart | session-start | hooks.json | Init state, load health |
| SessionStart | drift-detector.sh | hooks.json (async) | Codebase spot-checks |
| UserPromptSubmit | context-flow.sh | hooks.json | Context + decision detection |
| PreToolUse | pre-dispatch.sh | **settings.json** | → migration-linter + plan-file-guard |
| PreToolUse | *(3 prompt hooks)* | hooks.json | Auth, PostgREST, pre-push checks |
| PostToolUse | post-dispatch.sh | **settings.json** | → edit/bash tracking + patterns |
| Stop | stop-gate.sh | hooks.json | 4-gate session end |
| PreCompact | pre-compact.sh | hooks.json | Preserve carry-over |
| SessionEnd | session-end-dispatch.sh | hooks.json | Write health metrics |

### 8 Context Files

Injected by `context-flow.sh` on keyword match: scoring, migration, pipeline, deploy, testing, payment, math, typescript.

### 3 Commands

`/session-end` · `/analyze-session` · `/review-decisions`

### 4 State Files (in `.claude/`, gitignored)

`undercurrent-state.local.md` (session state) · `undercurrent-health.local.md` (health log) · `undercurrent-proposals.local.md` (rule proposals) · `undercurrent-decisions.local.md` (decision journal)

---

## Making Changes

**Always edit in `undercurrent-plugin/`** (source of truth). Then sync:

```bash
bash scripts/sync-plugin.sh
# Restart Claude Code for hook changes
```

Syncs to: plugin cache (runtime) + `undercurrent-v1/.claude-plugin/` (mirror).

**Add a skill:** Create `skills/<name>/SKILL.md` with YAML frontmatter → sync.
**Add a hook (PreToolUse/PostToolUse):** Add routing in the dispatcher script → sync + restart.
**Add a hook (other events):** Add to `hooks/hooks.json` → sync + restart.
**Add a context file:** Create in `context/` + add keywords in `context-flow.sh` → sync.

---

## Troubleshooting

**PreToolUse/PostToolUse not firing?** They must be in `~/.claude/settings.json`, not plugin `hooks.json`. Use format: `"bash C:/path/to/script.sh"` — quoted full paths silently fail.

**Paths mangled in state file?** Re-sync to get the `ENVIRON`-based `state-io.sh` (awk `-v` mangles Windows backslashes).

**Cache hash changed?** Update paths in `settings.json` after plugin updates.

**Skills not appearing?** Each needs `SKILL.md` with YAML frontmatter containing trigger phrases in `description`.

---

## File Structure

```
undercurrent-plugin/
  .claude-plugin/plugin.json
  hooks/
    hooks.json
    session-start
    scripts/
      pre-dispatch.sh, post-dispatch.sh     # Dispatchers (settings.json)
      post-edit-dispatch.sh                  # Edit tracking, commit nudge
      post-bash-dispatch.sh                  # Bash tracking, test detection
      migration-linter.sh                    # DENY now() in migrations
      plan-file-guard.sh                     # DENY plan overwrites
      context-flow.sh                        # Keyword context injection
      drift-detector.sh                      # Async codebase checks
      pattern-template.sh                    # Exemplar injection
      stop-gate.sh                           # Session end gates
      pre-compact.sh, session-end-dispatch.sh
      lib/ (escape-json, json-extract, state-io)
  skills/          # 16 skill directories
  commands/        # 3 slash commands
  agents/          # conversation-analyzer
  context/         # 8 domain context files
  scripts/         # sync-plugin.sh
```

---

## Windows Gotchas

| Issue | Fix |
|-------|-----|
| `awk -v` mangles `\U`, `\t` in paths | Use `ENVIRON` instead |
| `cut -d:` splits at drive letter | Strip prefix with `sed` first |
| `grep -c \|\| echo 0` double-outputs | Guard with `grep -q` first |
| Quoted bash exe path in hooks | Use plain `bash` on PATH |

---

## Version History

- **2.1.0** — Dispatcher architecture, global plugin (no project guards), Windows path fixes
- **2.0.0** — Full organism: 16 skills, 14 hooks, 1 agent, 8 context files, 3 commands
- **1.0.0** — Initial scaffold (session-start hook only)
