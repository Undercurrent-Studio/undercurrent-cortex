# Design Doc Template

Use this template for `tasks/design-[feature-name].md`. Fill in each section before implementation.

---

```markdown
# Design: [Feature Name]

## Problem Statement
[1-2 sentences: what problem does this solve, for whom, and why now?]

## Out of Scope
[Explicit list of what this feature does NOT include. Prevents scope creep.]

## Data Requirements
- **Sources**: [which APIs, tables, or external data?]
- **Schema changes**: [new tables, columns, migrations needed?]
- **Cache strategy**: [TTL, cache tags, tier-awareness (free vs pro)?]
- **Volume estimate**: [how many rows, how often updated?]

## Architecture
- **New files**: [list with full paths, marked [NEW]]
- **Modified files**: [list with full paths]
- **Dependencies**: [new packages? new env vars? new GitHub Secrets?]
- **Component pattern**: [server component, client component, streaming section?]

## Implementation Waves
Each wave must be independently shippable. Commit after each.

- **Wave 1**: [atomic deliverable — what it builds, what it touches]
- **Wave 2**: [atomic deliverable]
- ...

## Institutional Checklist
All must be "yes" before shipping:
- Sub-second loads
- All states handled: loading, empty, error
- Every number traceable to its source
- Works at 3am unattended
- Information density over whitespace
- No half-built sections

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| [risk 1] | [what breaks] | [how to handle] |

## Test Plan
- [what tests to write]
- [what to verify manually]
- [regression tests for existing behavior]
```

---

## Rules

- Design doc goes in `tasks/design-[feature-name].md` (canonical location per CLAUDE.md)
- Never in `docs/plans/`
- Fill in BEFORE implementation, not after
- Update if design changes mid-implementation
- Reference from plan file: "See `tasks/design-[feature].md` for full design"
