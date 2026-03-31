keywords: collaboration pattern, workflow pattern, synthesis, curate memory, how we work, reusable workflow, memory tier, collaboration file

# Synthesis Memory Context

You have a synthesis memory system at `~/.cortex/synthesis/`. It contains:

## Collaboration Patterns (`collaboration.md`)
- Loaded every session-start. Contains patterns about how you and the user work together.
- Entries tagged `[unconfirmed]` have been observed once — treat as hypothesis, not fact. Confirmed when Reinforced >= 2.
- `Applied` count tracks how often a pattern was consciously used. High-applied = high-value.
- `Importance` (high/medium/low) derived from evidence gate: user action = high, repetition/process = medium.
- `Negative scope` lists contexts where the pattern should NOT apply (e.g., utility projects).
- Anti-patterns (under "Anti-Patterns" theme) describe what NOT to do. Sourced from `[correction]` tags.

## Reusable Workflows (`workflows/`)
- Index at `workflows/_index.md` loaded every session-start.
- Detail files loaded on domain match (scope tags match task domain).
- Each workflow has numbered steps, "When to use" guidance, and metadata.

## Writing to synthesis files
- Session-end automatically extracts patterns via evidence gates:
  1. **User action gate** (high importance): specific pushback/correction/approval
  2. **Repetition gate** (medium): appeared 2+ times
  3. **Process gate** (medium): reproducible sequence with good/bad outcome
- **Conflict checking before writes**: Read existing entries. ADD (new) / UPDATE (variant) / NOOP (duplicate). Default to NOOP.
- New entries get `[unconfirmed]` tag until Reinforced >= 2.
- `Applied` count incremented when an existing pattern is used in a session.
- Evidence links use project-qualified format: `project-name:memory/YYYY-MM-DD.md#section`.

## PreCompact capture
For long sessions, write `[synthesis-candidate]` tags in the journal to anchor insights before compaction:
`[synthesis-candidate] Will pushed back on scope — wants comprehensive design before building`

## Curation
- `/cortex:curate-memory` runs the memory-synthesis agent.
- Agent merges duplicates, reorganizes themes, tags stale/provisional entries.
- Agent creates `.bak` backup before any modifications.
- Agent NEVER deletes — only merges, reorganizes, and flags.
