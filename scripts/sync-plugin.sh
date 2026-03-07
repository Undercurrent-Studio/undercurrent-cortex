#!/usr/bin/env bash
set -euo pipefail

# Undercurrent Plugin Sync Script
# Syncs source of truth to cache + v1 mirror + user skills
# Usage: bash scripts/sync-plugin.sh

SOURCE="C:/Users/whflo/Desktop/Code Projects/undercurrent-plugin"
CACHE="C:/Users/whflo/.claude/plugins/cache/claude-plugins-official/undercurrent/55b58ec6e564"
V1_MIRROR="C:/Users/whflo/Desktop/Code Projects/undercurrent-v1/.claude-plugin"
SKILLS="C:/Users/whflo/.claude/skills"

echo "=== Undercurrent Plugin Sync ==="
echo "Source: $SOURCE"
echo ""

# --- Phase 1: Clean stale artifacts ---
echo "[1/4] Cleaning stale artifacts..."

# Remove nested hooks/hooks/ from cache and v1 mirror
rm -rf "$CACHE/hooks/hooks"
rm -rf "$V1_MIRROR/hooks/hooks"

# Remove stale post-commit-log files
rm -f "$CACHE/hooks/post-commit-log"
rm -f "$V1_MIRROR/hooks/post-commit-log"

echo "  Cleaned: nested hooks/hooks/, post-commit-log"

# --- Phase 2: Sync to cache ---
echo "[2/4] Syncing to cache..."

# Hooks: clean target scripts+lib, then copy fresh
rm -rf "$CACHE/hooks/scripts"
cp -r "$SOURCE/hooks/scripts" "$CACHE/hooks/scripts"
cp "$SOURCE/hooks/hooks.json" "$CACHE/hooks/hooks.json"
cp "$SOURCE/hooks/hooks.json" "$CACHE/hooks.json"
cp "$SOURCE/hooks/session-start" "$CACHE/hooks/session-start"
cp "$SOURCE/hooks/run-hook.cmd" "$CACHE/hooks/run-hook.cmd" 2>/dev/null || true

# Other directories
for dir in skills commands agents context; do
  if [ -d "$SOURCE/$dir" ]; then
    rm -rf "$CACHE/$dir"
    cp -r "$SOURCE/$dir" "$CACHE/$dir"
  fi
done

# Plugin manifest
mkdir -p "$CACHE/.claude-plugin"
cp "$SOURCE/.claude-plugin/plugin.json" "$CACHE/.claude-plugin/plugin.json"

echo "  Synced: hooks, skills, commands, agents, context, plugin.json"

# --- Phase 3: Sync to v1 mirror ---
echo "[3/4] Syncing to v1 project mirror..."

# Hooks: clean and copy
rm -rf "$V1_MIRROR/hooks/scripts"
mkdir -p "$V1_MIRROR/hooks"
cp -r "$SOURCE/hooks/scripts" "$V1_MIRROR/hooks/scripts"
cp "$SOURCE/hooks/hooks.json" "$V1_MIRROR/hooks/hooks.json"
cp "$SOURCE/hooks/session-start" "$V1_MIRROR/hooks/session-start"
cp "$SOURCE/hooks/run-hook.cmd" "$V1_MIRROR/hooks/run-hook.cmd" 2>/dev/null || true

# Other directories
for dir in skills commands agents context; do
  if [ -d "$SOURCE/$dir" ]; then
    rm -rf "$V1_MIRROR/$dir"
    cp -r "$SOURCE/$dir" "$V1_MIRROR/$dir"
  fi
done

# Plugin manifest
mkdir -p "$V1_MIRROR/.claude-plugin"
cp "$SOURCE/.claude-plugin/plugin.json" "$V1_MIRROR/.claude-plugin/plugin.json"

echo "  Synced: hooks, skills, commands, agents, context, plugin.json"

# --- Phase 4: Sync skills to user-level directory ---
echo "[4/4] Syncing skills to ~/.claude/skills/..."

skill_count=0
for skill_dir in "$SOURCE/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  rm -rf "$SKILLS/$skill_name"
  cp -r "$skill_dir" "$SKILLS/$skill_name"
  skill_count=$((skill_count + 1))
done

echo "  Synced: $skill_count skills"

# --- Verification ---
echo ""
echo "=== Verification ==="

errors=0

# Count hooks in hooks.json
hook_count=$(grep -c '"type"' "$CACHE/hooks/hooks.json" 2>/dev/null || echo "0")
if [ "$hook_count" = "14" ]; then
  echo "Hook registrations in cache: $hook_count OK"
else
  echo "WARNING: Hook registrations in cache: $hook_count (expected 14)"
  errors=$((errors + 1))
fi

# Check root hooks.json matches
if diff -q "$CACHE/hooks.json" "$CACHE/hooks/hooks.json" > /dev/null 2>&1; then
  echo "Root + hooks/ hooks.json in sync: OK"
else
  echo "WARNING: Root hooks.json differs from hooks/hooks.json"
  errors=$((errors + 1))
fi

# Check no stale artifacts remain
if [ ! -d "$CACHE/hooks/hooks" ]; then
  echo "No nested hooks/hooks in cache: OK"
else
  echo "WARNING: nested hooks/hooks still in cache"
  errors=$((errors + 1))
fi

if [ ! -d "$V1_MIRROR/hooks/hooks" ]; then
  echo "No nested hooks/hooks in v1: OK"
else
  echo "WARNING: nested hooks/hooks still in v1"
  errors=$((errors + 1))
fi

# Check settings.json has no hook registrations
if grep -q '"hooks"' "$HOME/.claude/settings.json" 2>/dev/null; then
  echo "WARNING: settings.json has hook registrations (should be plugin-managed)"
  errors=$((errors + 1))
else
  echo "No hooks in settings.json: OK"
fi

echo ""
if [ "$errors" -eq 0 ]; then
  echo "All checks passed. Restart Claude Code to pick up changes."
else
  echo "$errors warning(s) found. Review above."
fi
