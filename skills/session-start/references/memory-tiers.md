# Memory Tiers — Single Source of Truth

The memory system has 6 tiers. Each tier has a specific purpose. No verbatim duplication across tiers — summarize upward only.

---

## Tier Hierarchy

| Tier | File | Purpose | Loaded When | Owner |
|------|------|---------|-------------|-------|
| Auto-memory | `~/.claude/projects/.../memory/MEMORY.md` | Structural guardrails, key patterns | Every message (system prompt) | Auto-updated by Claude |
| Project memory | `MEMORY.md` (project root) | Personal context, preferences, goals, decisions | Session start (read explicitly) | Claude updates, Will reviews |
| Daily journal | `memory/YYYY-MM-DD.md` | Session log, real-time decisions, carry-overs | Session start (read/create) | Claude writes in real-time |
| Lessons | `tasks/lessons.md` | Active gotchas, prevention rules | Session start (filtered by domain) | Claude writes after corrections |
| Architecture | `CLAUDE.md` | Permanent rules, stack definition, workflow | Always loaded (system prompt) | Will owns, Claude proposes |
| Design docs | `tasks/design-[feature].md` | Feature-specific plans and specs | On demand during implementation | Claude writes, Will approves |

---

## Rules

### No Duplication
- Each fact lives in exactly one tier
- Higher tiers summarize lower tiers (journal details → MEMORY.md summary → auto-memory essential)
- If the same information appears in two tiers, remove the less-authoritative copy

### Size Limits
- Auto-memory (`~/.claude/projects/.../MEMORY.md`): 200 lines max — only the first 200 are loaded into system prompt
- Project memory (`MEMORY.md`): no hard limit, but curate aggressively — this is the comprehensive profile
- Daily journals: 25 lines max per session entry (signal over noise)
- Lessons: one entry per class of problem (deduplicate on pattern match)

### Update Rules
- **Auto-memory**: Update when structural patterns are confirmed across multiple sessions. Keep concise — every line costs context window.
- **Project memory**: Update preferences, goals, key decisions. Replace stale entries (don't just append).
- **Journals**: Write in real-time as events happen. Never backfill from memory.
- **Lessons**: Write immediately after a correction. Include pattern + prevention rule.
- **CLAUDE.md**: Only modify with Will's approval. Propose changes, don't make them.
- **Design docs**: Write before implementation (Phase 2 of feature-design-flow). Update if design changes.

### Conflict Resolution
If two tiers disagree:
1. `CLAUDE.md` wins over everything (permanent rules)
2. `tasks/lessons.md` wins over MEMORY.md (lessons are correction-driven, more current)
3. Today's journal wins over yesterday's (most recent context)
4. If documentation.md conflicts with CLAUDE.md, CLAUDE.md is correct — update documentation.md

### Domain-Scoped Loading
At session start, only load lessons relevant to the current task domain:
- DB/Supabase/PostgREST → surface all DB lessons
- Pipeline/cron/sync-tickers → surface pipeline lessons
- Auth/RLS/middleware → surface auth lessons
- React/Next.js/components → surface frontend lessons
- SEC/EDGAR/XBRL → surface SEC lessons
- Scoring/V10/V11 → surface scoring lessons

Surface ALL matches within a domain. Do not limit to "last 5."
