---
name: pattern-escalation
description: This skill should be used when a problem class has appeared 2 or more times across sessions — escalates recurring patterns up through the memory tier hierarchy.
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
