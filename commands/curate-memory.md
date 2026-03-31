---
name: curate-memory
description: Run the memory-synthesis agent to curate collaboration patterns, workflows, and project file organization
---

Launch the `memory-synthesis` agent to perform a full curation pass on synthesis memory files.

The agent will:
1. Back up collaboration.md before any changes
2. Scan for duplicate or overlapping entries and merge them
3. Reorganize themes if they've grown unwieldy
4. Tag provisional entries (reinforced 1x, 20+ sessions old)
5. Tag stale entries (last validated 30+ sessions ago)
6. Sync workflow index with actual files
7. Strengthen descriptions where reinforcements added nuance
8. Check reference integrity across all _index.md files
9. Check if collaboration.md should be split (>20 entries)
10. Generate collaboration narrative if due (~30 sessions)
11. Check file organization (archive candidates, research consolidation)

No arguments needed. The agent reads the synthesis directory automatically.
