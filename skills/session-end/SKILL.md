---
name: session-end
description: This skill should be used when wrapping up a working session in the Undercurrent project — writes journal entry, captures carry-over, runs reasoning audit and pattern escalation check.
version: 0.1.0
---

# Session End

**TL;DR**: Always write 3-line journal. Scale up only if something notable happened.

## Always (every session) — append to `memory/YYYY-MM-DD.md`
- What happened (1 line)
- Any carry-over for next session — tag `[carry-over]` (1 line, or "none")
- Quality bar: did what shipped meet institutional-grade? (1 line, or "n/a")
- Tag entry with `[session-end]`

## If something notable happened (code written, decision made, bug fixed, correction received)

**Step 1 — Full journal entry**:
- **Decisions + rationale**: Why X over Y. One line each.
- **What broke + fix**: Root cause → fix. One line each.
- **Patterns recognized**: Any recurring class of problem.
- **Mid-session pins**: Confirm any decisions pinned mid-session were captured.
Keep total entry under 25 lines. Signal over noise.

**Step 2 — Reasoning audit** (answer honestly, one line each):
1. Did I jump to implementation before fully understanding the problem?
2. Did I catch all architectural implications, or did any surface late?
3. Was there a simpler solution I overlooked or dismissed?
If any "yes, I missed something" → add as `[reasoning-miss]`.

**Step 3 — Pattern escalation check**:
For each journal item: seen this class of problem in `tasks/lessons.md` or prior journals?
- YES, 2+ times → invoke `undercurrent:pattern-escalation`
- NO → journal only

**Step 4 — Auto-memory sync**:
Any structural pattern or decision made today → update `~/.claude/projects/.../memory/MEMORY.md`.
Edit/replace stale entries. Never just append. Stay under 200 lines.

**Step 5 — System health check** (1 line, every session):
Did the compounding loop produce signal or noise today? Log as `[system-health]`.
If session-start didn't fire or skills were skipped — note it.

**What counts as notable**: touched code, made an architectural choice, received a correction, fixed a bug, or spent more than 10 minutes on anything.

**Run session-end before closing every working session.** It takes 2 minutes.
