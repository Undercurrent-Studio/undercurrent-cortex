---
name: uninstall
description: Guide for cleanly removing all Cortex plugin artifacts from your system — bootstrap entries, state files, and plugin registration.
---

# Uninstall Cortex

Follow these steps to cleanly remove the Cortex plugin and all its artifacts.

## Step 1: Remove bootstrap entries from global settings

Open `~/.claude/settings.json` and remove all hook entries that contain `"_cortex_bootstrap": true`. These are in the `hooks` object under events: PreToolUse, PostToolUse, PreCompact, Stop, SessionEnd, UserPromptSubmit.

You can verify which entries to remove by searching for `_cortex_bootstrap` in the file. Remove the entire hook entry (the object containing `"_cortex_bootstrap": true`), and if a matcher group's `hooks` array becomes empty, remove the entire group. If an event's array becomes empty, remove the event key.

## Step 2: Remove plugin state files (per-project)

In each project where Cortex was active, delete the `.claude/cortex/` directory:

```bash
rm -rf .claude/cortex/
```

Also remove any legacy flat files if present:

```bash
rm -f .claude/cortex-*.local.md
```

## Step 3: Uninstall the plugin

```bash
claude plugins uninstall cortex@undercurrent-studio
```

## Step 4: Verify

Restart Claude Code. Confirm no Cortex hooks fire on session start (no statusline, no bootstrap messages).
