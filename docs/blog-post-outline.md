# How We Built a Self-Improving AI Coding Assistant

> Blog post outline — expand each section with 2-3 paragraphs, code snippets, and screenshots.

---

## 1. The Problem: AI Assistants Have Amnesia

- Every session starts from zero — no memory of what went wrong last time
- No enforcement of project rules — the AI repeats mistakes you already fixed
- No awareness of session quality — can't tell if it's helping or hurting

## 2. The Organism Metaphor

- Why biological systems? Each system has a clear role, they compose naturally, and failures are isolated
- 13 systems mapped to real developer needs: immune (enforcement), nervous (state tracking), circulatory (context injection), skeletal (lifecycle), etc.
- The metaphor keeps the architecture legible — "the immune system blocked a dangerous migration" is instantly understandable

## 3. Enforcement vs Advisory: The Spectrum

- Some things must be blocked (DENY hooks): `now()` in partial indexes, plan file overwrites
- Some things should nudge (advisory): commit cadence, documentation updates, test coverage
- Stop gates: 4 checks before session end — uncommitted edits, docs, tests, carry-over
- The 2-block escape hatch: after 2 consecutive blocks on the same gate, let the developer through

## 4. Adaptive Learning: Health-Driven Behavior

- 12 metrics per session: reasoning misses, edits per commit, test files modified, topology classification
- Rolling averages over last 10 sessions — the organism knows its own health trend
- Behavior modulation: degrading health → cautious mode (adds "plan before acting" reminders)
- Dynamic thresholds: high edits/commit → lower commit nudge threshold (nudge sooner)

## 5. Evolution Proposals: Self-Modifying Assistants

- The conversation-analyzer agent watches for recurring correction patterns
- Proposes new rules: lessons, context keywords, skill updates, even hook rules
- Approve/reject lifecycle with duplicate detection
- Hook rules require manual review (safety gate) — the organism can't modify its own enforcement without human approval

## 6. What We Learned Building This

- **Hook reliability is fragile**: Claude Code plugin hooks.json is unreliable for most events (bug #34573). We built a bootstrap system that injects hooks into global settings.json on every session start
- **Windows path handling in bash**: Drive letters, backslash escapes in awk, MSYS path translation — every one burned us at least once
- **Idempotency is everything**: Every hook must handle being called twice, with stale data, or with no data at all
- **Testing bash at scale**: 26 test scripts covering unit, integration, edge cases, and regressions. Mock JSON input, sandbox directories, fixture factories
- **Context injection must be deterministic**: Keyword-based matching with glob syntax, not regex — immune to injection from user prompts

## 7. What's Next

- **Hook profiles**: `minimal` (enforcement only), `standard` (+ learning), `strict` (full organism). Different projects need different levels of intervention.
- **Official marketplace submission**: Making Cortex discoverable to all Claude Code users
- **Domain packs**: Project-specific skills and context files as separate plugins that compose with the core organism
- **Semantic memory**: Local MCP server with SQLite + embeddings for cross-session context retrieval (currently file-based only)

---

## Suggested Visuals

- Screenshot of the two-line statusline (heart color, health metrics)
- Diagram of the 13 systems and how they connect (which hooks fire which systems)
- Before/after comparison: session without Cortex vs with Cortex (carry-over, stop gates, health tracking)
- Code snippet of `get_profile()` showing the config resolution chain
- Terminal output of the test suite (26 tests, colored pass/fail)
