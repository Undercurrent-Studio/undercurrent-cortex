---
name: pattern-escalation
description: This skill should be used when a problem class has appeared 2+ times across sessions — escalates recurring patterns up through the memory tier hierarchy.
version: 0.1.0
---

# Pattern Escalation

**TL;DR**: Escalate recurring patterns up 3 tiers: lessons.md → MEMORY.md → CLAUDE.md.

## Level 1 — `tasks/lessons.md`
Add/update: problem → root cause → fix → prevention rule.
If variant of existing lesson: UPDATE that entry. Do not duplicate.

## Level 2 — `MEMORY.md` (project root)
Add one-liner to relevant section. Format: `**Pattern**: Rule.`
Ensures every future session-start reads it.

## Level 3 — `CLAUDE.md` (architectural patterns only)
Criteria: affects schema, pipeline design, security, or data integrity.
Flag to Will before committing. Do NOT auto-commit CLAUDE.md changes.

## Memory curation (every ~10 sessions or when lessons.md > 40 entries)
Classify each lesson:
- Structural → promote one-liner to MEMORY.md, remove detail from lessons.md
- Active → keep
- Obsolete → delete
Goal: lessons.md stays actionable, not a graveyard.

## Skill accuracy check
Whenever a skill's advice is followed and produces a wrong result: update the skill immediately.
Don't wait for pattern-escalation. Stale skills give confident wrong guidance.
Pipeline numbers, DB patterns, and institutional checklist items are the most likely to drift.

## Proposal-aware escalation

Evolution proposals live at `.claude/cortex/proposals.local.md`. Each proposal has:
- `id` (YYYYMMDD-HHMMSS-slug), `status` (pending/approved/rejected/expired), `domain`, `occurrences`, `severity`
- `type`: hook-rule | skill-update | claude-md-amendment
- `probation=3`: new hooks run in warn-only mode for 3 sessions before blocking

### Escalation path
1. **1st occurrence** — Lesson captured in `tasks/lessons.md`
2. **2nd occurrence** — Existing lesson updated with new variant
3. **3rd+ occurrence** — Conversation-analyzer generates a proposal with evidence
4. **User review** — Proposals surfaced at session start; reviewed via `/analyze-session`
5. **Approved** — Implementer applies the change, updates proposal `status=applied` with commit SHA
6. **Rejected** — User marks `status=rejected` with reason

### Amplification path
When a lesson has been followed consistently (5+ sessions since written, 0 recurrences in that domain):
1. **Skill reference** — Add as "Known pitfall" in the relevant SKILL.md
2. **Hook enforcement** — If detectable by static analysis of tool input (file paths, code patterns, command strings), propose a new hook matcher
3. **All new hooks include `probation=3`** — warn-only for 3 sessions, then blocking

### Review protocol (at session start)
When `session-start` surfaces pending proposals:
1. Read each pending proposal
2. Assess: still relevant? evidence strong? risk acceptable?
3. Mark `status=approved` (implement now), `status=rejected` (with reason), or leave pending
4. Approved proposals get implemented in the current session if time allows

### Staleness rule
Proposals pending for 10+ sessions without review → mark `status=expired`. The pattern may resurface later if it recurs, generating a fresh proposal with updated evidence.

---
## See Also
- [session-end](../session-end/SKILL.md) — Session end triggers pattern escalation check for recurring issues [lifecycle]
- [session-start](../session-start/SKILL.md) — Session start surfaces pending escalation proposals for review [lifecycle]
- [systematic-debugging](../systematic-debugging/SKILL.md) — Debugging discovers patterns that feed into escalation [upstream]
