---
name: session-end
description: This skill should be used when wrapping up a working session — writes journal entry, captures carry-over, runs reasoning audit and pattern escalation check.
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
Tag explicit user corrections (user says "that's wrong", corrects a factual claim, or redirects a wrong approach) with `[correction]`.

**Step 3 — Pattern escalation check**:
For each journal item: seen this class of problem in `tasks/lessons.md` or prior journals?
- YES, 2+ times → invoke `cortex:pattern-escalation`
- NO → journal only

**Step 4 — Auto-memory sync**:
Any structural pattern or decision made today → update `~/.claude/projects/.../memory/MEMORY.md`.
Edit/replace stale entries. Never just append. Stay under 200 lines.

**Step 5 — System health check** (1 line, every session):
Did the compounding loop produce signal or noise today? Log as `[system-health]`.
If session-start didn't fire or skills were skipped — note it.

**Step 6 — Health metrics** (1 line per metric):
Assess the 5 health metrics defined in `references/health-metrics.md`:
1. Compounding signal-to-noise (did skills produce useful guidance?)
2. Session-start coverage (did the protocol execute fully?)
3. Pattern capture rate (did all corrections/decisions get logged?)
4. Memory freshness (is MEMORY.md clean and under 200 lines?)
5. Lesson deduplication (any duplicate lessons.md entries?)

Log as `[health-metrics]`:
```
[health-metrics] signal-noise=good, session-start=complete, capture=100%, memory=fresh, dedup=clean
```

**Adaptive immunity trigger**: If today's journal contains 2+ `[correction]` tags OR 1+ `[reasoning-miss]` tag, invoke `/analyze-session` for a full adaptive immunity scan before completing session-end. This is the primary feedback mechanism for the self-improvement loop. Also invoke if 3+ consecutive sessions show degraded health metrics (low capture rate, stale memory).

**What counts as notable**: touched code, made an architectural choice, received a correction, fixed a bug, or spent more than 10 minutes on anything.

See `examples/journal-entry.md` for a model journal entry with proper tags.

**Step 7 — Write health row** (non-negotiable, every session):
The SessionEnd hook is unreliable (~40% fire rate). The skill is the primary path for health row writes. Run this Bash command:

```bash
SID=$(cat .claude/cortex/current-session.id 2>/dev/null || true) && SCRIPT=$(ls -t ~/.claude/plugins/cache/undercurrent-studio/cortex/*/hooks/scripts/session-end-dispatch.sh 2>/dev/null | head -1 || true) && [ -n "$SCRIPT" ] && echo "{\"session_id\":\"${SID}\"}" | bash "$SCRIPT" || echo "session-end-dispatch not found"
```

This reads the current session_id (written by session-start) and pipes it as JSON to the dispatch script so it finds the correct state file. Without the session_id, the script may pick the wrong session.

After running, verify `.claude/cortex/health.local.md` was updated — the last line's date should match today.
If the script is not found, log `[system-health] session-end-dispatch not found — health row skipped` in the journal.
The SessionEnd hook still runs as a backup if it fires, but the dedup guard (`health_written=true` in the state file) prevents duplicate rows.

**Step 8 — Display session statusline diff** (every session):
Display the organism statusline at the end, showing what changed during the session. Compare the values from session start (displayed in your first response) against current values. Format:

```
── Session Pulse ──────────────────────────────
START  ✏️  0 edits · 📦 0 commits · 🧪❌ · 📄❌
END    ✏️  4 edits · 📦 2 commits · 🧪✅ · 📄✅
       💚 thriving │ 🧠 63 absorbed │ 🧬 0 mutations queued │ → stable
───────────────────────────────────────────────
```

Show the START line (from session start), the END line (current values), and the organism health line (current). This gives the user a visible summary of session productivity.

**Run session-end before closing every working session.** It takes 2 minutes.
