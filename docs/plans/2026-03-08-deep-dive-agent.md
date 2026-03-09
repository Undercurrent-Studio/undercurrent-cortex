# Deep-Dive Research Agent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an exhaustive research agent that produces world-class analytical reports on any topic — competitors, markets, technology, codebase, ideation — with browser capabilities and strategic output.

**Architecture:** Single agent file (`agents/deep-dive.md`) + slash command (`commands/deep-dive.md`). Agent uses all tools including Playwright browser for live product investigation. Writes reports incrementally to file. Auto-splits large topics into linked sub-reports.

**Tech Stack:** Claude Code plugin system (YAML frontmatter + markdown), Playwright MCP for browser

**Design doc:** `C:\Users\whflo\.claude\plans\jaunty-squishing-river.md`

## Audit Findings (applied)

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | IMPORTANT | Agent-creator would reinterpret/weaken the system prompt | Write agent file directly using full design spec |
| 2 | IMPORTANT | Output dirs (tasks/research/, docs/research/) may not exist | Agent Phase 1 creates directory if needed |
| 3 | IMPORTANT | Agent starts with fresh context — no CLAUDE.md | System prompt instructs to read CLAUDE.md for codebase topics |
| 4 | MINOR | skill-reviewer reviews skills not agents | Still run for description/triggering quality |
| 5 | MINOR | `git add -A` in Task 4 | Changed to specific file |
| 6 | MINOR | Sync path needs verification | Added verification step |

---

### Task 1: Create the deep-dive agent

**Files:**
- Create: `agents/deep-dive.md`

**Step 1: Write the agent file directly**

Write the full agent file with YAML frontmatter + system prompt. Source: the complete system prompt from the design doc (`jaunty-squishing-river.md`, lines 69-262). The frontmatter follows the `conversation-analyzer.md` pattern exactly.

Key elements to include:
- **Frontmatter**: name (`deep-dive`), description (with 4 `<example>` blocks), model (`inherit`), color (`cyan`). NO `tools` field (all tools).
- **System prompt body**: Identity, Capabilities (with Playwright MCP tool name prefixes), 5 Core Rules, 6-Phase Methodology, Report Template, Constraints
- **Audit fix #2**: Phase 1 must include "Create the output directory if it doesn't exist"
- **Audit fix #3**: Capabilities section must include "For codebase research: read CLAUDE.md and documentation.md first"

**Step 2: Commit**

```bash
cd "c:/Users/whflo/Desktop/Code Projects/undercurrent-plugin"
git add agents/deep-dive.md
git commit -m "feat: add deep-dive research agent"
```

---

### Task 2: Create the /deep-dive command

**Files:**
- Create: `commands/deep-dive.md`

**Step 1: Write the command file**

Follow the exact format of existing commands (name + description only in frontmatter, no arguments field):

```markdown
---
name: deep-dive
description: Launch an exhaustive deep-dive research session on any topic — competitors, markets, technology, codebase, ideation
---

Launch the `deep-dive` agent to conduct exhaustive research on the user's specified topic.

The agent will:
1. Scope the topic and create a research plan
2. Conduct broad discovery (web search, browser visits, codebase exploration)
3. Deep-investigate each sub-topic sequentially, writing findings to file incrementally
4. Cross-validate findings and assign confidence levels
5. Synthesize insights and strategic recommendations
6. Quality-audit the final report

Pass the user's topic or research question directly to the agent.
```

**Step 2: Commit**

```bash
cd "c:/Users/whflo/Desktop/Code Projects/undercurrent-plugin"
git add commands/deep-dive.md
git commit -m "feat: add /deep-dive slash command"
```

---

### Task 3: Validate plugin structure

**Step 1: Run `plugin-dev:plugin-validator`**

Validate the undercurrent-plugin at `c:/Users/whflo/Desktop/Code Projects/undercurrent-plugin/`

Expected: all checks pass — agent frontmatter valid, command frontmatter valid, plugin structure intact.

**Step 2: Fix any validation issues found**

---

### Task 4: Quality review

**Step 1: Run `plugin-dev:skill-reviewer`**

Review the deep-dive agent's description for triggering accuracy and example coverage. Note: this tool is designed for skills, so focus on its feedback about the description/triggering quality rather than agent-specific architecture.

**Step 2: Apply any quality improvements suggested**

**Step 3: Commit fixes (if any)**

```bash
cd "c:/Users/whflo/Desktop/Code Projects/undercurrent-plugin"
git add agents/deep-dive.md
git commit -m "refactor: apply quality review improvements to deep-dive agent"
```

---

### Task 5: Sync and verify

**Step 1: Verify sync target exists**

```bash
ls "c:/Users/whflo/Desktop/Code Projects/undercurrent-v1/.claude-plugin/agents/"
ls "c:/Users/whflo/Desktop/Code Projects/undercurrent-v1/.claude-plugin/commands/"
```

**Step 2: Copy files to undercurrent-v1 plugin cache**

```bash
cp "c:/Users/whflo/Desktop/Code Projects/undercurrent-plugin/agents/deep-dive.md" "c:/Users/whflo/Desktop/Code Projects/undercurrent-v1/.claude-plugin/agents/"
cp "c:/Users/whflo/Desktop/Code Projects/undercurrent-plugin/commands/deep-dive.md" "c:/Users/whflo/Desktop/Code Projects/undercurrent-v1/.claude-plugin/commands/"
```

**Step 3: Verify files are in place**

```bash
ls "c:/Users/whflo/Desktop/Code Projects/undercurrent-v1/.claude-plugin/agents/"
ls "c:/Users/whflo/Desktop/Code Projects/undercurrent-v1/.claude-plugin/commands/"
```

Expected: `deep-dive.md` appears in both directories alongside existing files.

**Step 4: Inform user to restart Claude Code session to pick up new agent**

---

## Post-Implementation Testing (after session restart)

1. `/deep-dive "stock research platform competitive landscape"` — should visit competitor sites, take screenshots, produce strategic report
2. "Do a deep dive on how our scoring pipeline works" — should trigger proactively, read codebase, produce technical report
3. Verify: report file created early (Phase 1), grows incrementally, has all sections, includes strategic recommendations
