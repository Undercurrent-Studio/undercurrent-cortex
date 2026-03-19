---
name: database-query-safety
description: This skill should be used before writing any Supabase or PostgREST query — 8 gotchas that cause silent failures.
version: 0.1.0
---

# Database Query Safety

**Auto-injected**: These gotchas are automatically surfaced via PreToolUse prompt hook every time you write Supabase/PostgREST code. No need to invoke this skill for routine query writing.

**When to invoke explicitly**: Deep-dive review of complex queries, debugging silent data loss, or onboarding to PostgREST patterns. See:
- `references/postgrest-gotchas.md` — detailed explanations with real incident history and code examples
- `examples/` — safe query patterns for common operations

---
## See Also
- [migration-safety](../migration-safety/SKILL.md) — Shared database domain: migration rules complement query safety patterns [related]
- [data-integrity](../data-integrity/SKILL.md) — Query safety is a prerequisite for data accuracy enforcement [enforcement]
- [security-posture](../security-posture/SKILL.md) — RLS policies and column-level security overlap with query patterns [related]
