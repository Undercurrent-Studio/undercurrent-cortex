---
name: validate-refs
description: This skill should be used to validate the knowledge graph health — checks broken links, orphaned files, stale code paths, canonical violations, and directive contradictions across reference files.
---

# Validate References

**TL;DR**: Run health checks on the reference file knowledge graph. Catches broken links, orphans, stale paths, canonical drift, and contradictions.

## When to Use
- After creating or modifying reference files
- Before major releases or deploys
- When reference staleness warnings appear in session-start
- Periodically as a maintenance check

## Checks (run all)

### 1. Broken See Also Links
For every `references/*.md` file, extract all See Also links. Verify:
- Target file exists
- If link has `#anchor`, verify the heading exists in the target file
- Report: `BROKEN: scoring.md links to signals.md#nonexistent-section`

### 2. Orphaned Reference Files
For every file in `references/`, check if at least one other file links to it (via See Also or @import in CLAUDE.md).
- Report: `ORPHAN: references/orphaned-file.md has zero inbound links`

### 3. Stale Code Path References
For every code path mentioned in reference files (matching `src/` or `supabase/` patterns), verify the path exists in the filesystem.
- Report: `STALE PATH: database.md references src/lib/supabase/old-file.ts (not found)`

### 4. Canonical Violations
For each `[canonical]` marker in reference files, grep all OTHER reference files for the same fact stated without a `(see X.md#section)` reference.
- Example: scoring weights appear in both scoring.md (canonical) and pipeline.md (without reference) = violation
- Report: `CANONICAL DRIFT: "33/33/33 weights" found in pipeline.md without reference to scoring.md#scoring-weights`

### 5. Directive Contradictions
Extract all directive lines from reference files (lines containing "always", "never", "must", "must not", "use", "prefer", "avoid"). Group by topic keywords. Flag contradictions.
- Report: `CONTRADICTION: scoring.md says "always use config.invert" but database.md says "use INVERTED_SUB_FACTORS"`

### 6. Frontmatter Completeness
Every reference file should have YAML frontmatter with: title, tokens, last-verified, canonical, triggers, governed-by.
- Report: `MISSING FRONTMATTER: api-routes.md missing "triggers" field`

### 7. Last-Verified Staleness
Check `last-verified` date in frontmatter. Flag files not verified in 30+ days.
- Report: `STALE: pipeline.md last verified 2026-02-15 (32 days ago)`

## Output Format

```
## Reference Validation Report — YYYY-MM-DD

### Summary
- Files scanned: N
- Broken links: N
- Orphans: N
- Stale paths: N
- Canonical violations: N
- Contradictions: N
- Missing frontmatter: N
- Stale (30+ days): N

### Findings
[list each finding with severity and fix suggestion]
```

## Execution

Run each check using Grep, Glob, and Read tools. Do NOT use bash grep — use the dedicated Grep tool for reliability. Present the full report to the user.

---
## See Also
- [plan-audit](../plan-audit/SKILL.md) — Gates 14-15 check reference coverage during planning [workflow]
- [pre-commit-checklist](../pre-commit-checklist/SKILL.md) — Domain-to-reference mapping warns on stale refs [workflow]
