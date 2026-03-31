---
name: session-end
description: This skill should be used when wrapping up a working session — writes journal entry, captures carry-over, runs reasoning audit and pattern escalation check.
version: 0.3.0
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
4. What decisions were made this session not yet in `.claude/cortex/decisions.local.md`? Log any missing ones now (same format as plan-audit Gate 17). This is the catch-all for sessions that skipped plan-audit.
5. What context would most help the next session in the first 30 seconds? Write this as a `[carry-over]` entry — not a summary, but what's *actionable* immediately.
If any "yes, I missed something" → add as `[reasoning-miss]`.
Tag explicit user corrections (user says "that's wrong", corrects a factual claim, or redirects a wrong approach) with `[correction]`.

**Step 2b — Synthesis extraction** (if something notable happened):
Review the full conversation for meta-cognitive patterns worth capturing. This is NOT about what happened (that's the journal) or what went wrong (that's lessons). This is about HOW we worked together and WHAT approaches were effective.

For each candidate insight, it must pass at least one **evidence gate**:
1. **User action gate** (→ importance: high): A specific user action (pushback, correction, approval, request) reveals this pattern. Quote or paraphrase it.
2. **Repetition gate** (→ importance: medium): This pattern appeared in 2+ distinct moments this session or across sessions.
3. **Process gate** (→ importance: medium): A specific sequence of steps produced a notably good/bad outcome that's reproducible.

If no gate passes, skip the candidate. When in doubt, skip — the pattern will recur.

**Conflict checking (before any write):** Read `~/.cortex/synthesis/collaboration.md` and compare the candidate against existing entries in the same theme:
- **ADD**: Genuinely new pattern. Write it with `[unconfirmed]` tag.
- **UPDATE**: Variant of existing entry. Increment Reinforced, update Last validated. If Reinforced reaches 2, remove `[unconfirmed]`.
- **NOOP**: Already captured. Skip.
Default to NOOP — only ADD when clearly distinct.

**Classify each finding:**
- **Collaboration pattern** (about how we interact) → append to `~/.cortex/synthesis/collaboration.md` under best-fit theme. Full metadata: Origin, Reinforced, Last validated, Scope, Importance (from gate), Negative scope, Evidence (project-qualified: `project-name:memory/YYYY-MM-DD.md#section`), Applied (starts at 0), Supersedes.
- **Anti-pattern** (about what DOESN'T work) → same format, under "Anti-Patterns" theme. Source: `[correction]` tags from this session or conversation-analyzer findings.
- **Reusable workflow** (discrete reproducible steps) → create detail file in `~/.cortex/synthesis/workflows/`, add one-liner to `_index.md`.
- **Applied tracking** → scan conversation for moments where an existing pattern was consciously followed. Increment that entry's `Applied` count and update `Last validated`.

**Conversation-analyzer cross-reference:** If the conversation-analyzer ran this session (adaptive immunity triggered), read its correction findings. Corrections that reveal collaboration preferences → anti-patterns. Don't duplicate the analyzer's work — consume its output.

**PreCompact capture note:** For long sessions (>90 min), write `[synthesis-candidate]` tags in the journal when collaboration-relevant moments occur mid-session. These anchor insights for extraction even if conversation detail is compacted.

Log what was written:
```
[synthesis] Added collaboration pattern: "Pattern name" (Theme) [unconfirmed]
[synthesis] Added anti-pattern: "Don't do X" (Anti-Patterns)
[synthesis] Reinforced workflow: workflow-name (now Nx)
[synthesis] Applied: "propose then iterate" (now Nx applied)
```

If nothing is synthesis-worthy this session, skip silently.

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

## Reference file tracking
Add to journal entry:
> **Reference files touched:** [list any references/*.md or rules/*-deep.md files created or updated]
> **Reference files needing update:** [list any that should be updated based on code changes this session]

If a reference file was modified this session, update its `last-verified` date in frontmatter.

**Run session-end before closing every working session.** It takes 2 minutes.

---
## See Also
- [session-start](../session-start/SKILL.md) — Session lifecycle pair: end writes memory, start reads it [lifecycle]
- [pattern-escalation](../pattern-escalation/SKILL.md) — Session end triggers pattern escalation check for recurring issues [downstream]
