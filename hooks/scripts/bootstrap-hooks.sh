#!/usr/bin/env bash
# bootstrap-hooks.sh - Inject all non-SessionStart hooks into ~/.claude/settings.json
# WORKAROUND: Plugin hooks.json command hooks are unreliable (bug #34573).
# SessionStart stays in hooks.json (proven working, keeps bootstrap alive).
# All other events are bootstrapped into GLOBAL settings.json (not project-level).
# Global settings.json is the only location proven to reliably fire hooks.
# See: https://github.com/anthropics/claude-code/issues/34573
# Remove this file when Anthropic confirms the bug is fixed and verified.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source state-io for PROJECT_DIR (needed for stale cleanup)
source "$SCRIPT_DIR/lib/state-io.sh" 2>/dev/null || true

# Fallback: derive PROJECT_DIR from git root
if [ -z "${PROJECT_DIR:-}" ]; then
  PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
fi

if [ -z "${PLUGIN_ROOT:-}" ]; then
  echo "bootstrap-hooks: no PLUGIN_ROOT, skipping" >&2
  exit 0
fi

# Global settings — the only location proven to reliably fire hooks
SETTINGS_FILE="${HOME}/.claude/settings.json"

# Also clean up stale bootstrap entries from the old project-level location
OLD_SETTINGS="${PROJECT_DIR:+${PROJECT_DIR}/.claude/settings.local.json}"

# Read profile for Python script
# Resolution: CORTEX_PROFILE env var → config file → "standard"
CORTEX_PROFILE="${CORTEX_PROFILE:-}"
if [ -z "$CORTEX_PROFILE" ] && [ -n "${PROJECT_DIR:-}" ] && [ -f "${PROJECT_DIR}/.claude/cortex/profile.local" ]; then
  CORTEX_PROFILE=$(head -1 "${PROJECT_DIR}/.claude/cortex/profile.local" 2>/dev/null | tr -d '[:space:]')
fi
case "$CORTEX_PROFILE" in
  minimal|strict) ;; # valid
  *) CORTEX_PROFILE="standard" ;;
esac

# Export for Python script
export PLUGIN_ROOT
export OLD_SETTINGS="${OLD_SETTINGS:-}"
export CORTEX_PROFILE

# Use python3 for reliable JSON manipulation
python3 - "$SETTINGS_FILE" <<'PYEOF'
import json
import sys
import os

settings_path = sys.argv[1]
plugin_root_ref = os.environ.get("PLUGIN_ROOT", "").replace("\\", "/")
old_settings_path = os.environ.get("OLD_SETTINGS", "")

# Bootstrap all events EXCEPT SessionStart into GLOBAL ~/.claude/settings.json.
# hooks.json is unreliable for other events (bug #34573).
# Each entry here must match the intended hook configuration exactly.
HOOKS_TO_INJECT = [
    {
        "event": "PreToolUse",
        "matcher": ".*",
        "hook": {
            "_cortex_bootstrap": True,
            "type": "command",
            "command": f'bash "{plugin_root_ref}/hooks/scripts/pre-dispatch.sh"',
            "timeout": 30,
            "async": False
        }
    },
    {
        "event": "PreCompact",
        "matcher": ".*",
        "hook": {
            "_cortex_bootstrap": True,
            "type": "command",
            "command": f'bash "{plugin_root_ref}/hooks/scripts/pre-compact.sh"',
            "async": False
        }
    },
    {
        "event": "Stop",
        "matcher": ".*",
        "hook": {
            "_cortex_bootstrap": True,
            "type": "command",
            "command": f'bash "{plugin_root_ref}/hooks/scripts/stop-gate.sh"',
            "async": False
        }
    },
    {
        "event": "PostToolUse",
        "matcher": ".*",
        "hook": {
            "_cortex_bootstrap": True,
            "type": "command",
            "command": f'bash "{plugin_root_ref}/hooks/scripts/post-dispatch.sh"',
            "timeout": 30,
            "async": True
        }
    },
    {
        "event": "SessionEnd",
        "matcher": ".*",
        "hook": {
            "_cortex_bootstrap": True,
            "type": "command",
            "command": f'bash "{plugin_root_ref}/hooks/scripts/session-end-dispatch.sh"',
            "async": False
        }
    },
    {
        "event": "UserPromptSubmit",
        "matcher": ".*",
        "hook": {
            "_cortex_bootstrap": True,
            "type": "command",
            "command": f'bash "{plugin_root_ref}/hooks/scripts/context-flow.sh"',
            "async": False
        }
    },
]

# Profile-aware event filtering
# minimal: only enforcement + state tracking + lifecycle
# standard/strict: all 6 events (strict enables proposals in session-start/context-flow, not here)
profile = os.environ.get("CORTEX_PROFILE", "standard")
MINIMAL_EVENTS = {"PreToolUse", "PostToolUse", "SessionEnd"}
if profile == "minimal":
    HOOKS_TO_INJECT = [h for h in HOOKS_TO_INJECT if h["event"] in MINIMAL_EVENTS]
    print(f"bootstrap-hooks: minimal profile — injecting {len(HOOKS_TO_INJECT)} events only", file=sys.stderr)

settings = {}
if os.path.isfile(settings_path):
    try:
        with open(settings_path, 'r', encoding='utf-8') as f:
            settings = json.load(f)
    except (json.JSONDecodeError, IOError):
        print("bootstrap-hooks: settings.json unreadable, creating fresh", file=sys.stderr)
        settings = {}

if "hooks" not in settings:
    settings["hooks"] = {}

hooks = settings["hooks"]
changed = False


def find_cortex_bootstrap(hook_list):
    """Find existing _cortex_bootstrap entries. Returns list of (group_idx, hook_idx, hook_obj)."""
    results = []
    for gi, group in enumerate(hook_list):
        for hi, h in enumerate(group.get("hooks", [])):
            if h.get("_cortex_bootstrap"):
                results.append((gi, hi, h))
    return results


def remove_cortex_bootstrap(hook_list):
    """Remove all cortex hook entries from an event's hook list.
    Matches entries with _cortex_bootstrap marker OR entries whose command
    contains a known cortex hook script name (catches unmarked orphans)."""
    CORTEX_SCRIPT_NAMES = [
        "pre-dispatch.sh", "post-dispatch.sh", "stop-gate.sh",
        "pre-compact.sh", "session-end-dispatch.sh", "context-flow.sh",
    ]
    def is_cortex_hook(h):
        if h.get("_cortex_bootstrap"):
            return True
        cmd = h.get("command", "")
        return any(name in cmd for name in CORTEX_SCRIPT_NAMES)
    for group in hook_list:
        group["hooks"] = [h for h in group.get("hooks", []) if not is_cortex_hook(h)]
    # Remove empty groups
    return [g for g in hook_list if g.get("hooks")]


for entry in HOOKS_TO_INJECT:
    event = entry["event"]
    matcher = entry["matcher"]
    hook = entry["hook"]
    expected_command = hook["command"]

    if event not in hooks:
        hooks[event] = []

    existing = find_cortex_bootstrap(hooks[event])

    if existing:
        # Check if existing bootstrap matches expected command and matcher
        all_match = True
        for gi, hi, h in existing:
            if h.get("command") != expected_command:
                all_match = False
                break
            # Also check matcher on the group
            if hooks[event][gi].get("matcher") != matcher:
                all_match = False
                break

        if all_match:
            print(f"bootstrap-hooks: {event} already correct, skipping", file=sys.stderr)
            continue

        # Stale entry — remove and re-inject
        print(f"bootstrap-hooks: {event} stale (command or matcher mismatch), replacing", file=sys.stderr)
        hooks[event] = remove_cortex_bootstrap(hooks[event])
        changed = True

    # Inject fresh entry
    found_group = False
    for group in hooks[event]:
        if group.get("matcher") == matcher:
            group["hooks"].append(hook)
            found_group = True
            break
    if not found_group:
        hooks[event].append({
            "matcher": matcher,
            "hooks": [hook]
        })
    changed = True
    print(f"bootstrap-hooks: injected {event} command hook", file=sys.stderr)

# Clean up empty events
for event in list(hooks.keys()):
    if not hooks[event]:
        del hooks[event]

if changed:
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    with open(settings_path, 'w', encoding='utf-8') as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print("bootstrap-hooks: wrote updated ~/.claude/settings.json", file=sys.stderr)
else:
    print("bootstrap-hooks: no changes needed", file=sys.stderr)

# Clean up stale bootstrap entries from old project-level settings.local.json
if old_settings_path and os.path.isfile(old_settings_path):
    try:
        with open(old_settings_path, 'r', encoding='utf-8') as f:
            old_settings = json.load(f)
        old_hooks = old_settings.get("hooks", {})
        old_changed = False
        for event in list(old_hooks.keys()):
            cleaned = remove_cortex_bootstrap(old_hooks[event])
            if len(cleaned) != len(old_hooks[event]):
                old_changed = True
                if cleaned:
                    old_hooks[event] = cleaned
                else:
                    del old_hooks[event]
        if old_changed:
            if not old_hooks:
                del old_settings["hooks"]
            with open(old_settings_path, 'w', encoding='utf-8') as f:
                json.dump(old_settings, f, indent=2, ensure_ascii=False)
                f.write('\n')
            print(f"bootstrap-hooks: cleaned stale entries from project settings.local.json", file=sys.stderr)
    except (json.JSONDecodeError, IOError, KeyError):
        pass  # Old file is broken or missing — ignore
PYEOF

exit 0
