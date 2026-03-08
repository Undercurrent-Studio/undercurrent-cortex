# Undercurrent Plugin

A Claude Code plugin that works like a **living organism** — 13 biological systems that learn, adapt, protect, and evolve across your coding sessions.

Built for the [Undercurrent](https://undercurrent.finance) stock research platform.

---

## What Does It Actually Do?

Imagine a second brain sitting alongside Claude that:

- **Remembers** every file you edit, every commit you make, every decision you explain
- **Blocks** dangerous operations before they happen (like using `now()` in a Postgres migration)
- **Injects context** when you mention a topic ("scoring" → here's how the scoring system works)
- **Nudges** you to commit when edits pile up, and validates commit message format
- **Guards** session end so you don't walk away with uncommitted work or stale docs
- **Watches** the outside world — did CI fail? Did someone push to remote? Any open PRs?
- **Heals** itself — corrupted state files get repaired automatically on boot
- **Adapts** its behavior based on your recent session quality
- **Proposes** its own improvements and waits for your approval
- **Tracks patterns** across sessions — which files keep getting re-edited, what domains you focus on

All of this happens through bash hooks that fire at specific moments in your Claude Code session.

---

## Setup

### Requirements

- **Claude Code** (CLI or VS Code extension)
- **Git Bash** on your PATH (Windows: comes with [Git for Windows](https://git-scm.com/))
- **GitHub CLI** (`gh`) — optional, but needed for the Sensory system (CI/PR checks)

### Installation

**Step 1:** Install the plugin via Claude Code's plugin system.

**Step 2:** Register dispatcher hooks in `~/.claude/settings.json`.

Claude Code's plugin system can't fire command hooks for PreToolUse/PostToolUse events — only prompt hooks work for those. The workaround is registering two dispatcher scripts globally:

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

> **Syntax:** Plain `bash` (not the full exe path). Forward slashes. No quotes around the script path. Matcher must be `".*"` (regex that matches all tools).

**Step 3:** Restart Claude Code.

---

## The 13 Systems — How They Work

Think of the plugin as a body. Each system has a specific job, and they work together.

### Systems 1-4: The Core Loop

These fire every session and handle the basics.

**1. Nervous System — State Tracking**
Every edit, commit, and tool call gets counted in a state file. The nervous system is how the organism "feels" what's happening — it's the raw sensory data that other systems read.

*Where:* `post-edit-dispatch.sh`, `post-bash-dispatch.sh`
*State:* `edits_since_last_commit`, `commits_count`, `tool_calls_count`, `[files_modified]` section

**2. Immune System — Dangerous Operation Blocking**
Before certain tools execute, the immune system checks if the operation is safe. If not, it blocks it with an explanation.

Examples of what gets blocked:
- `now()` or `CURRENT_DATE` in a migration file → PostgreSQL requires IMMUTABLE functions in partial indexes
- Overwriting a plan file without reading it first → plan-file-guard prevents accidental plan destruction
- Auth/RLS patterns that expose server secrets → prompt-based pre-tool checks

*Where:* `pre-dispatch.sh` → routes to `migration-linter.sh` + `plan-file-guard.sh`. Three additional prompt hooks in `hooks.json`.

**3. Circulatory System — Context Injection**
When you mention a topic keyword in your prompt, the circulatory system injects the right context file. This is how domain knowledge flows to where it's needed.

| You say... | Plugin injects... |
|-----------|-------------------|
| "scoring", "percentile" | Scoring architecture, pillar weights, transfer functions |
| "pipeline", "cron" | Pipeline timing, circuit breakers, batch sizes |
| "migration", "schema" | Migration safety rules, IMMUTABLE gotchas |
| "stripe", "payment" | Payment flow, webhook handling, subscription lifecycle |
| "deploy", "production" | Deploy checklist, Vercel constraints |
| "test", "vitest" | Test patterns, mock helpers, coverage rules |
| "math", "calculation" | Data type discipline (BIGINT vs NUMERIC), rounding rules |
| "typescript", "type" | TypeScript patterns, noUncheckedIndexedAccess rules |

It also detects **decision language** ("I decided", "let's go with", "[decision]") and prompts you to add metadata (rationale, alternatives, confidence) to build a decision journal.

*Where:* `context-flow.sh` reads your prompt → matches keywords → injects from `context/` files

**4. Skeletal System — Session Lifecycle**
The skeleton that everything hangs on. Initializes state at session start, loads health history, runs an async codebase spot-check (drift detector), and writes a 12-field health row at session end.

*Where:* `session-start` (SessionStart hook), `drift-detector.sh` (async), `session-end-dispatch.sh` (SessionEnd hook)

---

### Systems 5-8: Intelligence Layer

These add learning, patterns, and guardrails.

**5. Digestive System — Pattern Templates**
When you create a new file in certain directories, the plugin injects a real example from the codebase as a convention reference. Instead of guessing the project's patterns, Claude gets a concrete exemplar.

*Where:* `pattern-template.sh` (PostToolUse on Write)

**6. Endocrine System — Commit Enforcement**
Nudges you to commit when edits accumulate. The threshold is dynamic — the Feedback system (System 12) can raise or lower it based on your recent session health. Also validates conventional commit format (`feat:`, `fix:`, `refactor:`, etc.) on `git commit`.

*Where:* `post-edit-dispatch.sh` (edit counting + nudge), `post-bash-dispatch.sh` (commit format validation)
*Default threshold:* 15 edits (adjustable by Feedback system)

**7. Memory System — Stop Gates**
When Claude tries to end the session (Stop event), 4 gates must pass:
1. All edits committed (no abandoned work)
2. Documentation updated (if code changed)
3. Tests mentioned or run
4. Carry-over resolved (no stale items from previous sessions)

If a gate fails, the session continues with a warning. After 2 consecutive blocks on the same gate, an escape hatch opens — sometimes you genuinely need to stop.

*Where:* `stop-gate.sh` (Stop hook)

**8. Reproductive System — Evolution Proposals**
The `conversation-analyzer` agent watches for recurring patterns across sessions and proposes new rules. These become "proposals" — the raw material that the Growth system (System 11) manages.

*Where:* `agents/conversation-analyzer.md` generates proposals → stored in `undercurrent-proposals.local.md`

---

### Systems 9-13: The v3 Expansion

These five systems were added to make the organism truly self-aware and adaptive.

**9. Sensory System — External Awareness**
The organism can now look *outside* the session. On every session start (and mid-session when you mention keywords like "CI" or "pipeline status"), it checks:

| Check | How | What you see |
|-------|-----|-------------|
| Remote commits | `git fetch --dry-run` | "Remote has new commits on origin/master since last fetch" |
| CI status | `gh run list --limit 3` | "CI FAILED: type-check. Run: gh run list --limit 3" |
| Open PRs | `gh pr list --state open` | "3 open PR(s) on this repo" |

Mid-session checks have a 5-minute cooldown so they don't fire repeatedly.

*Where:* `sensory-check.sh` (called by `session-start` and `context-flow.sh`)
*State fields:* `last_sensory_check`, `last_remote_head`, `last_ci_status`

**10. Healing/Repair System — Self-Recovery**
On every boot, the organism checks its own state files for damage and fixes what it finds:

| Check | What it fixes |
|-------|--------------|
| Corrupted state file | Backs up and continues (missing `session_id=` field) |
| Out-of-range counters | Clamps to valid range (e.g., `edits_since_last_commit` capped at 0-1000) |
| Bloated file lists | Deduplicates `[files_modified]` when >200 entries |
| Missing health header | Rebuilds `trend_direction=stable` + summary fields |
| Oversized health log | Prunes to last 100 rows when >500 lines |
| Missing file separators | Adds `---` to proposals/decisions files |
| Stale temp files | Deletes `*.tmp.*` files older than 60 minutes |
| Old state backups | Removes `state-backup-*` files older than 7 days |
| Bloated cross-session file | Prunes entries older than 30 days when >500 lines |

*Where:* `lib/validate-organism.sh` (sourced by `session-start`)
*Output:* `issues|repairs|detail` — e.g., `2|2|clamped edits_since_last_commit from 9999 to 1000, cleaned 3 stale temp files`

**11. Growth/Adaptation System — Proposal Lifecycle**
The Reproductive system (System 8) creates proposals. The Growth system manages their lifecycle:

- **Surfacing:** On each session start, pending proposals are shown with increasing urgency (surfaced count increments)
- **Approve:** Say "approve proposal" → safe types auto-apply (lessons, context keywords, skill updates). Risky types (hook rules) get flagged for manual review
- **Reject:** Say "reject proposal" → status set to rejected, won't surface again
- **Duplicate detection:** Won't apply content that already exists in the target file

6 proposal types:
| Type | Target | Apply method |
|------|--------|-------------|
| `lesson` | `tasks/lessons.md` | Append |
| `context-keyword` | `context-flow.sh` | Append |
| `skill-update` | A skill file | Append |
| `claude-md-amendment` | `CLAUDE.md` | Append |
| `context-file` | New context file | Create |
| `hook-rule` | A hook script | **Manual review only** |

*Where:* `apply-proposal.sh` (called by `context-flow.sh` on approve/reject keywords)
*Trigger phrases:* "approve proposal", "reject proposal", "show proposals", "list proposals"

**12. Feedback Loop System — Health-Driven Behavior**
The organism reads its own health history and adjusts how it behaves:

| Health signal | Behavioral change |
|--------------|------------------|
| `trend_direction=degrading` | Switch to **cautious mode** — context-flow adds "plan before acting" reminders on code-related prompts |
| Session topology = `high-churn` | Switch to **cautious mode** |
| High `avg_edits_per_commit` | Lower the commit nudge threshold (nudge sooner) |
| Everything healthy | Normal mode, default thresholds |

Cautious mode doesn't block anything — it just adds a gentle reminder to think before acting. It's the organism's way of saying "recent sessions were rough, let's be more careful."

*Where:* `session-start` (computes mode + threshold from health file) → writes `mode=cautious|normal` and `commit_nudge_threshold=N` to state → `context-flow.sh` and `post-edit-dispatch.sh` read these values
*State fields:* `mode`, `commit_nudge_threshold`

**13. Social/Communication System — Cross-Session Intelligence**
Patterns that only emerge across multiple sessions:

- **Domain tagging:** Each session gets a domain tag based on which `src/` subdirectory was most edited (e.g., `scoring`, `pipeline`, `components`). Written as the 12th field in each health row.
- **Cross-session file tracking:** Every file edited gets logged with its session count and last-edit date in `undercurrent-cross-session.local.md`. Format: `filepath|session_count|last_session_date`.
- **Pattern detection** (runs at session start):
  - *Domain clustering:* "Last 4 sessions were all scoring work" — surfaces focus patterns
  - *Session length trends:* Compares recent session durations to historical average
  - *Hot files:* Files edited in 5+ sessions get called out — they may need refactoring or are simply central to the architecture

*Where:* `session-end-dispatch.sh` (writes domain tag + updates cross-session file) → `session-start` (reads and analyzes patterns)
*State file:* `.claude/undercurrent-cross-session.local.md`

---

## Components Summary

### 16 Skills

| Layer | Skills |
|-------|--------|
| **Mission** | product-identity, security-posture, data-integrity |
| **Domain** | database-query-safety, pipeline-change-checklist, migration-safety, scoring-change-checklist, github-actions-safety |
| **Workflow** | feature-design-flow, pre-commit-checklist, deploy-readiness, plan-audit, plan-estimation |
| **Learning** | session-start, session-end, pattern-escalation |

### 14 Hooks

| Event | Script | Where | What |
|-------|--------|-------|------|
| SessionStart | session-start | hooks.json | Init state, load health, healing, sensory, feedback, social |
| SessionStart | drift-detector.sh | hooks.json (async) | Codebase spot-checks |
| UserPromptSubmit | context-flow.sh | hooks.json | Context injection, decision detection, cautious mode, sensory/proposal keywords |
| PreToolUse | pre-dispatch.sh | **settings.json** | Routes to migration-linter + plan-file-guard |
| PreToolUse | *(3 prompt hooks)* | hooks.json | Auth, PostgREST, pre-push checks |
| PostToolUse | post-dispatch.sh | **settings.json** | Routes to edit/bash tracking + patterns |
| Stop | stop-gate.sh | hooks.json | 4-gate session end |
| PreCompact | pre-compact.sh | hooks.json | Preserve carry-over |
| SessionEnd | session-end-dispatch.sh | hooks.json | Health metrics, domain tag, cross-session tracking |

### 3 Commands

| Command | What it does |
|---------|-------------|
| `/session-end` | Write journal entry, carry-over, reasoning audit, health metrics |
| `/analyze-session` | Deep adaptive immunity scan (triggered by corrections or reasoning misses) |
| `/review-decisions` | Review decisions from 7-14 days ago for validation |

### 5 State Files

All in `.claude/`, all gitignored:

| File | Purpose |
|------|---------|
| `undercurrent-state.local.md` | Current session: edit counts, commit counts, mode, thresholds, file list |
| `undercurrent-health.local.md` | Historical: one row per session with 12 metrics |
| `undercurrent-proposals.local.md` | Pending/applied/rejected evolution proposals |
| `undercurrent-decisions.local.md` | Decision journal entries with metadata |
| `undercurrent-cross-session.local.md` | File edit frequency across sessions |

### 8 Context Files

Injected by `context-flow.sh` on keyword match: scoring, migration, pipeline, deploy, testing, payment, math, typescript.

---

## Making Changes

**Always edit in `undercurrent-plugin/`** (source of truth). Then sync:

```bash
bash scripts/sync-plugin.sh
# Restart Claude Code for hook changes
```

Syncs to: plugin cache (runtime) + `undercurrent-v1/.claude-plugin/` (mirror).

| Task | How |
|------|-----|
| Add a skill | Create `skills/<name>/SKILL.md` with YAML frontmatter → sync |
| Add a hook (PreToolUse/PostToolUse) | Add routing in the dispatcher script → sync + restart |
| Add a hook (other events) | Add to `hooks/hooks.json` → sync + restart |
| Add a context file | Create in `context/` + add keywords in `context-flow.sh` → sync |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| PreToolUse/PostToolUse not firing | Must be in `~/.claude/settings.json`, not plugin `hooks.json`. Use `"bash C:/path/to/script.sh"` — quoted full paths silently fail |
| Paths mangled in state file | Re-sync to get `ENVIRON`-based `state-io.sh` (awk `-v` mangles Windows backslashes) |
| Cache hash changed after update | Update paths in `settings.json` to match new cache directory |
| Skills not appearing | Each needs `SKILL.md` with YAML frontmatter containing trigger phrases in `description` |
| State file corrupted | Delete it — the Healing system will rebuild on next boot |
| Sensory checks slow | Requires `gh` CLI authenticated. Without it, CI/PR checks are skipped silently |

---

## File Structure

```
undercurrent-plugin/
  .claude-plugin/plugin.json
  hooks/
    hooks.json
    session-start                        # SessionStart: init + healing + sensory + feedback + social
    scripts/
      pre-dispatch.sh                    # PreToolUse dispatcher (settings.json)
      post-dispatch.sh                   # PostToolUse dispatcher (settings.json)
      post-edit-dispatch.sh              # Edit tracking + commit nudge
      post-bash-dispatch.sh              # Bash tracking + commit format validation
      migration-linter.sh               # Block now() in migrations
      plan-file-guard.sh                # Block plan overwrites
      context-flow.sh                    # Keyword context + decisions + cautious mode + sensory/proposals
      drift-detector.sh                 # Async codebase spot-checks
      pattern-template.sh               # Convention exemplar injection
      stop-gate.sh                       # 4-gate session end
      sensory-check.sh                   # External awareness (git, CI, PRs)
      apply-proposal.sh                  # Proposal approve/reject lifecycle
      pre-compact.sh                    # Preserve carry-over on context compaction
      session-end-dispatch.sh           # Health metrics + domain tag + cross-session tracking
      lib/
        escape-json.sh                  # JSON string escaping
        json-extract.sh                 # Lightweight JSON field extraction
        state-io.sh                      # read_field/write_field/read_section/append_to_section
        validate-organism.sh            # Healing system: 9 self-repair checks
  skills/          # 16 skill directories
  commands/        # 3 slash commands
  agents/          # conversation-analyzer (evolution proposal generator)
  context/         # 8 domain context files
  scripts/         # sync-plugin.sh
```

---

## Windows Gotchas

| Issue | Fix |
|-------|-----|
| `awk -v` mangles `\U`, `\t` in paths | Use `ENVIRON` instead: `VAR="$val" awk '... ENVIRON["VAR"] ...'` |
| `cut -d:` splits at drive letter `C:` | Strip prefix with `sed` first, then `cut` |
| `grep -c` outputs count even on no-match | Guard with `grep -q` first, then `grep -c` |
| Quoted bash exe path in hooks | Use plain `bash` (must be on PATH) |
| No `timeout` command in Git Bash | `sensory-check.sh` uses `run_with_timeout()` fallback |

---

## Version History

- **3.0.0** — 13 systems: added sensory, healing, growth, feedback, social
- **2.1.0** — Dispatcher architecture, global plugin (no project guards), Windows path fixes
- **2.0.0** — Full organism: 16 skills, 14 hooks, 1 agent, 8 context files, 3 commands
- **1.0.0** — Initial scaffold (session-start hook only)
