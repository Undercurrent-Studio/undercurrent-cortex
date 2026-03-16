---
name: session-start
description: This skill should be used when starting or resuming a session — reads memory, creates journal, surfaces carry-over and domain-relevant lessons.
version: 0.1.0
---

# Session Start

**TL;DR**: Always: MEMORY.md + journal + carry-over. Scale up based on task scope.

## Always (every session)
1. Read `MEMORY.md` (project root) — personal context, preferences, active decisions
2. Read or create `memory/YYYY-MM-DD.md` — if missing, create: `# Journal - YYYY-MM-DD` + `## HH:MM - Session start`. Do not ask. Just create it.
3. Check `memory/[yesterday].md` — if hook surfaced a missed-session-end warning, run `/cortex:session-end` retrospective for yesterday first. Then check last 3 entries for `[carry-over]` tags and surface them.

## If task is non-trivial (new feature, bug, architectural decision — not a quick question)
4. Read `tasks/todo.md` + scan `tasks/lessons.md` by domain:
   - DB/Supabase/PostgREST → surface all DB lessons
   - Pipeline/cron/sync-tickers → surface pipeline lessons
   - Auth/RLS/middleware → surface auth lessons
   - React/Next.js/components → surface frontend lessons
   - SEC/EDGAR/XBRL → surface SEC lessons
   Surface all matches. Do not limit to "last 5."

## If touching architecture, schema, or pipeline
5. Read `documentation.md`. Run `git log --oneline -5 documentation.md` — if not touched in 3+ commits while code changed, flag staleness to Will before proceeding.

## State file protocol
6. Check `tasks/todo.md` for in-progress items (unchecked boxes). If the previous session left work mid-flight, complete it before starting new tasks.

## Carry-over re-injection
When surfacing carry-over items from previous sessions, explicitly write them as the first item in today's journal entry. Do not just acknowledge them — write them to the journal so they are tracked:
```
## HH:MM - Session start
- Carry-over from [date]: [carry-over] Item description here
```

See `references/memory-tiers.md` for the full memory hierarchy and rules.

**Default to reading** — skip only if the session is purely conversational (no files, no decisions, no code). When in doubt, read.
