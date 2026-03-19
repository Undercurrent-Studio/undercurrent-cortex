---
name: create-skill
description: Interactively scaffold a new Cortex skill with proper structure, frontmatter, and context-flow wiring
---

# Create Skill

Guide the user through creating a new Cortex skill. This is an interactive flow — ask questions, then generate files.

## Step 1: Gather Information

Ask the user for:

1. **Skill name** (kebab-case, e.g., `api-design-review`)
2. **One-line description** (what it does and when it should trigger)
3. **Layer** — which layer does this skill belong to?
   - **Mission**: Core invariants that must always hold (security, data integrity)
   - **Domain**: Project-specific technical patterns (database safety, migration rules)
   - **Methodology**: Development process patterns (TDD, systematic debugging)
   - **Workflow**: Multi-step procedures (feature design, deploy readiness)
   - **Learning**: Session lifecycle and retrospective (session start/end, pattern escalation)
4. **Trigger conditions** — when should Claude invoke this skill? Write as natural language examples.
5. **Rigid or flexible?**
   - **Rigid**: Follow exactly as written (checklists, security invariants, migration rules)
   - **Flexible**: Adapt to context (debugging flows, design processes)

## Step 2: Generate the Skill

Create the directory and SKILL.md file at `skills/{name}/SKILL.md`.

### Frontmatter

```yaml
---
name: {name}
description: {description with trigger phrases and examples, following existing skill patterns}
version: 0.1.0
---
```

### Body — Rigid Skills

```markdown
# {Title}

**TL;DR**: {one-line summary}

## The Rules / Invariants / Checklist
{numbered list of concrete, verifiable rules}

## When to Apply
{specific situations where this skill fires}

## Implementation Reference
{file paths, function names, patterns to check}
```

### Body — Flexible Skills

```markdown
# {Title}

**TL;DR**: {one-line summary}

## Phase 1 — {first phase name}
{steps}

## Phase 2 — {next phase name}
{steps}

## When to Stop / Escalate
{conditions that indicate the flow should change}
```

## Step 3: Optional References Directory

Ask: "Does this skill need reference documents (templates, checklists, examples)?"

If yes, create `skills/{name}/references/` and help the user define what goes there.

## Step 4: Optional Context File Wiring

Ask: "Should this skill have a context file that auto-injects when relevant keywords are mentioned?"

If yes:
1. Ask for keywords (comma-separated)
2. Warn about substring collisions — context-flow uses `[[ "$prompt" == *"keyword"* ]]` substring matching. Short keywords like `go`, `pip`, `gin`, `chan` will match inside common words. Test mentally: "would this keyword appear inside any unrelated word?"
3. Create `context/{name}.md` with `keywords:` first line and a summary of when to invoke the skill
4. Remind: "First keyword match wins across ALL context files. Keywords must be distinct."

## Step 5: Version Bump Reminder

Say: "Skill created. Before committing, bump the version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Commit format: `feat: add {name} skill`."

## Reference: Keyword Design Rules

When creating context files, avoid generic keywords that match inside common words:

| Bad Keyword | Matches Inside | Better Alternative |
|-------------|---------------|-------------------|
| `go` | "go ahead", "let's go" | `golang`, `go.mod` |
| `pip` | "pipeline" | `pyproject.toml`, `pytest` |
| `gin` | "engine", "login", "origin" | `fiber`, `cobra` |
| `chan` | "change", "channel" | `goroutine` |

Test each keyword: "Would this substring appear in a normal conversation about something else?"

Context files scan alphabetically — if two files could match, the earlier filename wins.
