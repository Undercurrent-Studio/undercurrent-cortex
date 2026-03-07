# Health Metrics — Definitions and Thresholds

5 metrics that measure whether the compounding intelligence loop is producing signal or noise. Assessed during session-end Step 6.

---

## 1. Compounding Signal-to-Noise

**Definition**: Did skills and hooks produce useful guidance, or just noise this session?

**Assessment**: Review each skill invocation this session. Was the guidance actionable (changed behavior, caught a bug, prevented a mistake) or irrelevant (triggered on wrong context, provided obvious information)?

**Threshold**: >50% of skill invocations produced actionable guidance.
**If failing**: Skills may have overly broad trigger descriptions. Note which skills fired unnecessarily — candidates for trigger refinement via pattern-escalation.

---

## 2. Session-Start Coverage

**Definition**: Did the session-start protocol execute fully?

**Checklist**:
- MEMORY.md read?
- Journal created/continued?
- Carry-over from previous session surfaced?
- Domain lessons loaded (if non-trivial task)?
- documentation.md staleness checked (if touching architecture)?

**Threshold**: All applicable items completed. Binary pass/fail.
**If failing**: Note which step was skipped and why. If session-start skill didn't fire, log as `[system-health]` concern.

---

## 3. Pattern Capture Rate

**Definition**: How many corrections, decisions, and notable events were logged vs discovered-but-not-logged?

**Assessment**: At session end, scan the conversation for: corrections received, architectural decisions made, bugs fixed, preferences expressed. Compare against journal entries. Any gap = missed capture.

**Threshold**: 100% capture — every correction and decision has a journal entry.
**If failing**: The memory system only works if entries are written. Missing entries = future sessions repeat mistakes.

---

## 4. Memory Freshness

**Definition**: Is the memory hierarchy clean and current?

**Checklist**:
- `MEMORY.md` (auto-memory) under 200 lines?
- No stale entries in MEMORY.md (outdated project status, completed phases still listed as active)?
- `tasks/lessons.md` entries unique per class (no duplicates of same pattern)?
- Today's journal has proper tags (`[session-end]`, `[carry-over]`, `[system-health]`)?

**Threshold**: All items pass.
**If failing**: Curate immediately — remove stale entries, deduplicate lessons, add missing tags.

---

## 5. Lesson Deduplication

**Definition**: Are lessons.md entries unique, or has the same class of problem been logged multiple times with slightly different wording?

**Assessment**: Scan lessons.md for entries about the same root cause (e.g., multiple entries about PostgREST `.update()` behavior). Each class of problem should have exactly one entry.

**Threshold**: Zero duplicates.
**If failing**: Merge duplicate entries into a single comprehensive entry. Use pattern-escalation to promote the merged lesson if it has 3+ occurrences.

---

## Logging Format

After assessing all 5 metrics, log a one-line summary as `[health-metrics]` in the journal:

```
[health-metrics] signal-noise=good, session-start=complete, capture=100%, memory=fresh, dedup=clean
```

If any metric is failing, note the specific issue:

```
[health-metrics] signal-noise=good, session-start=MISSING(carry-over not surfaced), capture=80%(missed 1 decision), memory=fresh, dedup=clean
```
